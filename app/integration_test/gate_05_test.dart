import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_generator.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_markdown.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/recording/domain/quick_capture_handoff.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/reminders/data/reminders_exporter.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';

import '../test/db/db_test_utils.dart';
import '../test/fakes/fake_call_guard.dart';
import '../test/fakes/fake_capture_backend.dart';
import '../test/fakes/fake_clock.dart';
import '../test/fakes/fake_llm_engine.dart';
import '../test/fakes/fake_reminders_platform.dart';
import '../test/fakes/fake_schema_grammar_converter.dart';

/// GATE-05 automatable half (docs/test-plans/gates/GATE-05.md). Real domain
/// code (hand-off, recording controller, Ask service, mind-map projection,
/// Reminders exporter, network gateway) runs against fakes for the hardware,
/// the model and the OS. Device, release-build and human rows are in
/// docs/test-plans/device/GATE-05.md and are all ⏳.
///   cd app && fvm flutter test integration_test/gate_05_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Tests run with cwd = app/.
  String read(String repoPath) => File('../$repoPath').readAsStringSync();

  testWidgets('[GATE-05/AC1] the gate script has one section per area and '
      'every Phase 2 stress case has a device row', (tester) async {
    final gate = read('docs/test-plans/gates/GATE-05.md');
    for (final area in [
      'S1 — Quick capture',
      'S2 — Profiles to a vault note',
      'S3 — Ask',
      'S4 — Mind map',
      'S5 — Reminders',
      'S6 — Stress',
      'S7 — Performance',
      'S8 — Egress',
      'S9 — Repository check',
    ]) {
      expect(gate, contains(area));
    }
    // The unmet Ask quality gates and Live Activity are stated, not hidden.
    expect(gate, contains('ASK-03'));
    expect(gate, contains('ASK-05'));
    expect(gate, contains('ask.enabled'));
    expect(gate, contains('AUD-13'));

    final plan = read('docs/test-plans/stress.md');
    final rows = read('docs/test-plans/device/GATE-05.md');
    for (var n = 26; n <= 32; n++) {
      expect(plan, contains('| D-$n |'), reason: 'D-$n in the stress plan');
      expect(rows, contains('D-$n'), reason: 'D-$n has a GATE-05 row');
    }
    // Nothing is claimed as run.
    expect(rows, isNot(contains('PASS')));
  });

  testWidgets('[GATE-05/AC2] every quick-capture entry only navigates; a '
      'recording needs a tap; a call stops it and it never auto-resumes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final entry in QuickCaptureEntry.values) {
        final capture = FakeCaptureBackend();
        final guard = FakeCallGuard();
        final controller = RecordingController(
          capture: capture,
          callGuard: guard,
          clock: const SystemClock(),
          isAppInForeground: () => true,
        );
        final opened = <QuickCaptureEntry>[];
        final handoff = QuickCaptureHandoff(
          source: _Source([_msg(entry: entry.name)]),
          navigateToRecord: opened.add,
        );
        expect(await handoff.consume(), QuickCaptureOutcome.navigated);
        expect(opened, [entry]);
        expect(controller.state.phase, RecordingPhase.idle, reason: '$entry');
        expect(capture.calls, isEmpty, reason: '$entry');

        // The user taps Record in the app; then a call arrives.
        expectOk(await controller.start(StartSource.inAppButton));
        expect(controller.state.phase, RecordingPhase.recording);
        guard.emit(CallGuardSignal.callActive, DateTime.now());
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.phase, RecordingPhase.paused);
        expect(controller.state.pauseCause, PauseCause.call);
        expect(capture.micOpen, isFalse);
        guard
          ..emit(CallGuardSignal.callEnded, DateTime.now())
          ..emit(CallGuardSignal.interruptionEnded, DateTime.now());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(controller.state.phase, RecordingPhase.paused);
        expect(capture.calls.whereType<ResumeCall>(), isEmpty);
        await controller.stop();
      }
    });
  });

  testWidgets('[GATE-05/AC2] an expired, replayed or malformed request from '
      'any entry never navigates or records', (tester) async {
    for (final entry in QuickCaptureEntry.values) {
      final capture = FakeCaptureBackend();
      final controller = RecordingController(
        capture: capture,
        callGuard: FakeCallGuard(),
        clock: const SystemClock(),
        isAppInForeground: () => true,
      );
      final opened = <QuickCaptureEntry>[];
      final handoff = QuickCaptureHandoff(
        source: _Source([
          _msg(entry: entry.name, remainingMs: 0),
          _msg(entry: entry.name),
          _msg(entry: entry.name),
          _msg(entry: entry.name, mode: 'start'),
          _msg(entry: entry.name, id: 'not-a-uuid'),
        ]),
        navigateToRecord: opened.add,
      );
      final outcomes = [for (var i = 0; i < 5; i++) await handoff.consume()];
      expect(outcomes, [
        QuickCaptureOutcome.expired,
        QuickCaptureOutcome.navigated,
        QuickCaptureOutcome.replayed,
        QuickCaptureOutcome.malformed,
        QuickCaptureOutcome.malformed,
      ]);
      expect(opened, hasLength(1));
      expect(controller.state.phase, RecordingPhase.idle);
      expect(capture.calls, isEmpty);
    }
  });

  testWidgets('[GATE-05/AC3] Ask answers across a seeded library with cited '
      'passages, refuses without evidence, and is unavailable on Mid/Low', (
    tester,
  ) async {
    final passages = [
      _passage('rec-a', 4000, 'Okay, beta ships on the 9th.'),
      _passage('rec-b', 9000, 'The warranty covers the battery for two years.'),
      _passage('rec-c', 15000, 'Launch is moved to April.'),
    ];
    AskService service(FakeLlmEngine e, {bool supported = true}) => AskService(
      retriever: _Retriever(passages),
      engine: e,
      grammarConverter: FakeSchemaGrammarConverter(),
      residency: ModelResidency(),
      deviceSupportsAsk: () => supported,
      modelInstalled: () => true,
      pipelineBusy: () => false,
      queueWait: const Duration(milliseconds: 20),
      queuePoll: const Duration(milliseconds: 5),
      idleUnload: const Duration(hours: 1),
    );
    String reply({
      required bool found,
      required String text,
      required String rec,
      required String t,
    }) => jsonEncode({
      'found': found,
      'answer': text,
      'citations': found
          ? [
              {'recording_id': rec, 't': t},
            ]
          : <Object>[],
    });

    final yes = expectOk(
      await service(
        FakeLlmEngine(
          tokens: [
            reply(
              found: true,
              text: 'The beta ships on the 9th.',
              rec: 'rec-a',
              t: '00:00:04',
            ),
          ],
        ),
      ).ask(const AskRequest(question: 'When does the beta ship?')),
    );
    expect(yes.outcome, AskOutcome.answered);
    expect(yes.citations.single.recordingId, 'rec-a');
    expect(yes.citations.single.tMs, 4000);

    final no = expectOk(
      await service(
        FakeLlmEngine(
          tokens: [reply(found: false, text: '', rec: '', t: '')],
        ),
      ).ask(const AskRequest(question: 'What is the capital of France?')),
    );
    expect(no.outcome, AskOutcome.notFound);
    expect(no.answer, kAskNotFoundText);
    expect(no.citations, isEmpty);

    final ghost = expectOk(
      await service(
        FakeLlmEngine(
          tokens: [
            reply(found: true, text: 'It is 9.', rec: 'rec-zzz', t: '00:00:04'),
          ],
        ),
      ).ask(const AskRequest(question: 'When does the beta ship?')),
    );
    expect(ghost.outcome, AskOutcome.notFound);

    final engine = FakeLlmEngine(
      tokens: [reply(found: true, text: 'x', rec: 'rec-a', t: '00:00:04')],
    );
    final low = await service(
      engine,
      supported: false,
    ).ask(const AskRequest(question: 'When does the beta ship?'));
    expect(low.failureOrNull, isA<UnsupportedFeatureFailure>());
    expect(engine.requests, isEmpty);
  });

  testWidgets('[GATE-05/AC3] a mind map from an extraction is valid and its '
      'Markdown export is inert', (tester) async {
    final result = await MindMapGenerator(method: MindMapMethod.projection)
        .generate(
          const MindMapInput(
            lines: [TranscriptLine(startMs: 0, text: 'We agreed to ship it.')],
            tier: DeviceTier.high,
            modelId: 'm',
            extraction: {
              'title': 'Plan',
              'summary': 's',
              'decisions': [
                {'text': 'Ship [x](https://example.com) <b>', 't': '00:00:00'},
              ],
              'action_items': [
                {'task': 'Send the deck', 'owner': 'Sam'},
              ],
            },
          ),
        );
    final tree = result.valueOrNull!.tree!;
    expect(validateMindMap(tree.toJson()), isEmpty);
    final md = mindMapStandaloneMarkdown(tree);
    expect(md, contains('Send the deck'));
    expect(md, isNot(contains('://')));
    expect(RegExp(r'(?<!\\)<').hasMatch(md), isFalse);
  });

  testWidgets('[GATE-05/AC1] Reminders export creates what the user chose '
      'once, and a revoked permission creates nothing', (tester) async {
    await tester.runAsync(() async {
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
      for (final body in ['Send the budget', 'Book the room']) {
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
      final exporter = RemindersExporter(
        platform: platform,
        db: db,
        clock: FakeClock(t0),
      );
      final all = (await exporter.candidates()).valueOrNull!;
      final one = [all.first];
      final first = (await exporter.export(one)).valueOrNull!;
      expect(first.created, 1);
      final again = (await exporter.export(one)).valueOrNull!;
      expect(again.created, 0);
      expect(platform.store, hasLength(1));

      platform.access = ReminderAccess.denied;
      final denied = await exporter.export([all.last]);
      expect(denied.failureOrNull, isA<PermissionFailure>());
      expect(platform.store, hasLength(1));
    });
  });

  testWidgets('[GATE-05/AC3] the Ask and mind-map budgets in budgets.json '
      'match the ASK-03 and MAP-01 task files', (tester) async {
    final budgets = jsonDecode(
      read('tools/bench/perf/budgets.json'),
    ) as Map<String, Object?>;
    final w = budgets['workloads']! as Map<String, Object?>;
    final ask = ((w['ask']! as Map)['tiers']! as Map)['high']! as Map;
    expect(ask['cold_first_answer_s'], 30);
    expect(ask['warm_first_answer_s'], 20);
    expect(ask['peak_rss_mib'], 4200);
    expect(((w['ask']! as Map)['tiers']! as Map)['mid'], isNull);
    final map = (w['mind_map']! as Map)['tiers']! as Map;
    expect(
      [
        for (final t in ['high', 'mid', 'low']) (map[t]! as Map)['step_s'],
      ],
      [30, 60, 120],
    );

    final askTask = read('tasks/14-product-phase2/ASK-03-ask-engine.md');
    expect(askTask, contains('≤ 30 s cold, ≤ 20 s warm'));
    expect(askTask, contains('≤ 4200 MiB'));
    final mapTask = read(
      'tasks/14-product-phase2/MAP-01-mind-map-generation.md',
    );
    expect(mapTask, contains('| High | ≤ 30 |'));
    expect(mapTask, contains('| Mid | ≤ 60 |'));
    expect(mapTask, contains('| Low | ≤ 120 |'));
  });

  testWidgets('[GATE-05/AC4] the release gateway reaches only the model '
      'hosts, never an integration host', (tester) async {
    final gateway = NetworkGateway(
      config: const NetworkConfig(
        allowedHosts: kModelHosts,
        redirectHosts: kModelRedirectHosts,
      ),
    );
    for (final host in kModelHosts) {
      expect(
        (await gateway.authorize(Uri.https(host, '/m.bin'))).isOk,
        isTrue,
        reason: host,
      );
    }
    for (final host in [
      'api.todoist.com',
      'api.notion.com',
      'graph.microsoft.com',
      'api.openai.com',
      'www.icloud.com',
      'us.aws.cdn.hf.co', // redirect-only
    ]) {
      expect(
        (await gateway.authorize(Uri.https(host, '/'))).isOk,
        isFalse,
        reason: host,
      );
    }
  });
  testWidgets('[GATE-05/AC5] the gate requires a human verifier and the '
      'repository check', (tester) async {
    final gate = read('docs/test-plans/gates/GATE-05.md');
    expect(gate, contains('tasks.py verify --all-done --run'));
    expect(gate, contains('A human, not an agent'));
    expect(
      read('docs/test-plans/device/GATE-05.md'),
      contains('[GATE-05/AC5]'),
    );
  });
}

class _Source implements QuickCaptureSource {
  _Source(this._queue);

  final List<QuickCaptureMessage?> _queue;

  @override
  Future<QuickCaptureMessage?> consumeRequest() async =>
      _queue.isEmpty ? null : _queue.removeAt(0);
}

QuickCaptureMessage _msg({
  String id = '3f2b8c5e-9d41-4a7b-8e6f-0c1d2e3f4a5b',
  String entry = 'iosWidget',
  String mode = 'navigate',
  int remainingMs = 9000,
}) => QuickCaptureMessage(
  id: id,
  entry: entry,
  mode: mode,
  remainingMs: remainingMs,
);

AskPassage _passage(String rec, int tMs, String text) => AskPassage(
  recordingId: rec,
  tMs: tMs,
  text: text,
  kind: AskPassageKind.transcript,
  recordedAt: DateTime(2026, 3, 2),
);

class _Retriever implements AskRetriever {
  _Retriever(this.passages);

  final List<AskPassage> passages;

  @override
  Future<Result<List<AskPassage>>> retrieve(AskQuery query) async =>
      Ok(passages);
}
