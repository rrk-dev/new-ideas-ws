import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_markdown.dart';
import 'package:vaultvoice/features/reminders/data/reminders_exporter.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_llm_engine.dart';
import '../../fakes/fake_reminders_platform.dart';
import '../../fakes/fake_schema_grammar_converter.dart';

class _Sink implements LogSink {
  final lines = <String>[];

  @override
  void write(LogRecord record) => lines.add(record.toJsonLine());

  @override
  Future<void> close() async {}
}

class _Retriever implements AskRetriever {
  @override
  Future<Result<List<AskPassage>>> retrieve(AskQuery query) async => Ok([
    AskPassage(
      recordingId: 'rec-sentinel',
      tMs: 4000,
      text: 'Zephyr merger closes on the 9th, call Anna on 555-0199.',
      kind: AskPassageKind.transcript,
      recordedAt: DateTime(2026, 3, 2),
    ),
  ]);
}

const _secrets = [
  'Zephyr',
  'merger',
  'Anna',
  '555-0199',
  'Quarterly secret',
  'rec-sentinel',
];

void _expectClean(Iterable<String> lines) {
  final dump = lines.join('\n');
  expect(dump, isNotEmpty);
  for (final s in _secrets) {
    expect(dump, isNot(contains(s)), reason: s);
  }
}

String _answer({
  bool found = true,
  String text = 'Zephyr merger closes on the 9th.',
  String recording = 'rec-sentinel',
  String t = '00:00:04',
}) => jsonEncode({
  'found': found,
  'answer': text,
  'citations': [
    {'recording_id': recording, 't': t},
  ],
});

void main() {
  group('[SEC-11/AC5] content-free logging on the Phase 2 paths', () {
    Future<void> ask(FakeLlmEngine engine, Logger log, {bool ok = true}) async {
      await AskService(
        retriever: _Retriever(),
        engine: engine,
        grammarConverter: FakeSchemaGrammarConverter(),
        residency: ModelResidency(),
        deviceSupportsAsk: () => true,
        modelInstalled: () => ok,
        pipelineBusy: () => false,
        log: log,
        queueWait: const Duration(milliseconds: 20),
        queuePoll: const Duration(milliseconds: 5),
        idleUnload: const Duration(hours: 1),
      ).ask(const AskRequest(question: 'Quarterly secret: when does Zephyr?'));
    }

    test(
      'Ask: success, not found, bad JSON, bad citation, missing model',
      () async {
        final sink = _Sink();
        final log = Logger(sinks: [sink]);
        await ask(FakeLlmEngine(tokens: [_answer()]), log);
        await ask(FakeLlmEngine(tokens: [_answer(found: false)]), log);
        await ask(FakeLlmEngine(tokens: ['{"found": tru']), log);
        await ask(FakeLlmEngine(tokens: [_answer(recording: 'ghost')]), log);
        await ask(FakeLlmEngine(tokens: [_answer(t: '09:59:59')]), log);
        await ask(FakeLlmEngine(tokens: [_answer()]), log, ok: false);
        _expectClean(sink.lines);
      },
    );

    test('Reminders: success and a host failure log counts only', () async {
      final db = VaultVoiceDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement('PRAGMA foreign_keys = ON');
      await seedRecording(db, 'r1');
      await db
          .into(db.extractions)
          .insert(
            ExtractionsCompanion.insert(
              id: 'e1',
              recordingId: 'r1',
              profileId: 'meeting',
              profileVersion: 1,
              modelId: 'llm',
              json: const {},
              valid: true,
              createdAt: t0,
            ),
          );
      for (final body in ['Call Anna about Zephyr', 'Send the merger deck']) {
        await db
            .into(db.actionItems)
            .insert(
              ActionItemsCompanion.insert(
                recordingId: 'r1',
                extractionId: 'e1',
                body: body,
              ),
            );
      }
      final platform = FakeRemindersPlatform();
      final sink = _Sink();
      final exporter = RemindersExporter(
        platform: platform,
        db: db,
        clock: FakeClock(t0),
        logger: Logger(sinks: [sink], clock: FakeClock(t0)),
      );
      final list = (await exporter.candidates()).valueOrNull!;
      platform.failKeys.add(list.first.keyed.key);
      await exporter.export(list);
      _expectClean(sink.lines);
    });

    test('Mind map Markdown makes hostile labels inert', () {
      final out = mindMapLabel(
        '[click](https://example.com) ![x](http://example.com/a.png) '
        '<script>x</script> {{secret}} [[Note]]',
      );
      expect(out, isNot(contains('://')));
      expect(RegExp(r'(?<!\\)<').hasMatch(out), isFalse);
      expect(out, isNot(contains('{{')));
      expect(out, isNot(contains('[[')));
      expect(RegExp(r'(?<!\\)\[').hasMatch(out), isFalse);
    });

    test('Ask answers render as plain text, never Markdown or HTML', () {
      for (final f in Directory('lib/features/ask/presentation').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        expect(
          RegExp(
            r'flutter_markdown|MarkdownBody|flutter_html|Html\(|launchUrl|'
            'webview',
          ).hasMatch(src),
          isFalse,
          reason: f.path,
        );
      }
    });
  });

  group('[SEC-11/AC5] quick-capture surfaces carry no recording data', () {
    // Everything a widget, tile, control or shortcut can see or send.
    final sources = [
      for (final d in [
        'ios/QuickCaptureShared',
        'ios/LumenWidgets',
        'ios/ShareExtension',
        'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/quickcapture',
      ])
        ...Directory(d)
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  RegExp(r'\.(swift|kt)$').hasMatch(f.path) &&
                  !f.path.endsWith('.g.kt'),
            ),
    ];

    String code(File f) => f
        .readAsLinesSync()
        .where((l) => !RegExp(r'^\s*(//|/?\*)').hasMatch(l))
        .join('\n');

    test('no transcript, title, summary, extraction or segment access', () {
      expect(sources.length, greaterThan(5));
      final banned = RegExp(
        'transcript|summary|extraction|segment|recordingTitle|'
        'actionItem|searchIndex|durationMs|noteBody',
        caseSensitive: false,
      );
      for (final f in sources) {
        expect(banned.hasMatch(code(f)), isFalse, reason: f.path);
      }
    });

    test('no network, microphone or file access in widget/tile code', () {
      final banned = RegExp(
        'URLSession|HttpURLConnection|AVAudioSession|AVAudioRecorder|'
        'AudioRecord|MediaRecorder|FileManager|openFileOutput|'
        'SharedPreferences',
      );
      for (final f in sources.where(
        (f) => !f.path.contains('ShareExtension'),
      )) {
        expect(banned.hasMatch(code(f)), isFalse, reason: f.path);
      }
    });
  });

  group('[SEC-11/AC1] audit and threat docs cover every Phase 2 flow', () {
    final audit = File('../docs/privacy-audit.md').readAsStringSync();
    final threats = File('../docs/threat-model.md').readAsStringSync();
    final device = File('../docs/test-plans/device/SEC-11.md');

    test(
      '[SEC-11/AC1] one audit row per flow P1–P8 and a signed checklist',
      () {
        for (var i = 1; i <= 8; i++) {
          expect(RegExp('^\\| P$i ', multiLine: true).hasMatch(audit), isTrue);
          expect(audit, contains('| P$i '));
        }
        expect(audit, contains('Signed checklist (Phase 2)'));
        expect(audit, contains('SEC-11-D9'));
        expect(device.existsSync(), isTrue);
      },
    );

    test('[SEC-11/AC2] every Phase 2 threat has a mitigation and a proof', () {
      for (var i = 23; i <= 32; i++) {
        final row = RegExp(
          '^\\| T$i \\|(.*)\\|\$',
          multiLine: true,
        ).firstMatch(threats);
        expect(row, isNotNull, reason: 'T$i');
        final cells = row!.group(0)!.split('|').map((c) => c.trim()).toList();
        // '', id, threat, STRIDE, sev, mitigation, proof, residual, ''
        expect(cells.length, 9, reason: 'T$i');
        expect(cells[5], isNotEmpty);
        expect(cells[6], isNotEmpty);
      }
      for (final topic in [
        'spoofing',
        'Another app invokes',
        'Lock Screen',
        'Ask answers',
        'mind-map labels',
        'another user',
        'did not select',
      ]) {
        expect(threats, contains(topic));
      }
    });

    test('docs never use the former product name', () {
      final old = String.fromCharCodes([
        86,
        97,
        117,
        108,
        116,
        86,
        111,
        105,
        99,
        101,
      ]);
      // The audit keeps the real HTTP User-Agent string; check the new text.
      final phase2 = audit.substring(audit.indexOf('## Phase 2 data flows'));
      for (final d in [phase2, threats, device.readAsStringSync()]) {
        expect(d, isNot(contains(old)));
      }
    });
  });
}
