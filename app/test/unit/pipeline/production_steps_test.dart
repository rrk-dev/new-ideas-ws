import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

final BuiltinProfiles _builtins = BuiltinProfiles.parse({
  for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
});

/// The built-in without `ground_to_transcript`: these wiring tests script
/// the model's answer, while the fake STT transcript is just `chunk_0`
/// (grounding is covered by `extraction_grounding_test.dart`).
Profile? _ungrounded(String id) {
  final p = _builtins[id];
  if (p == null) return null;
  final json = p.toJson();
  (json['post_process']! as List).remove('ground_to_transcript');
  return Profile.fromJson(json);
}

const Map<String, Object?> _validMeeting = {
  'title': 'Release sync',
  'summary': 'We agreed on the date.',
  'attendees': ['Ana'],
  'decisions': ['Ship Friday'],
  'action_items': [
    {'task': 'Send notes', 'owner': 'Ana', 'due': null, 't': '00:00:00'},
  ],
  'open_questions': <String>[],
  'topics': ['release'],
};

String _date(DateTime t) {
  final d = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class _Run {
  _Run(this.db, this.paths, {ScriptedLlm? llm, this.withProfiles = true})
    : llm = llm ?? ScriptedLlm(output: jsonEncode(_validMeeting));

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final ScriptedLlm llm;
  final bool withProfiles;
  final stt = ScriptedStt();
  final vault = FakeVaultWriter();

  Future<String> run(String recordingId) async {
    final o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: stt,
        llm: llm,
        vault: vault,
        profiles: withProfiles ? (id) async => _ungrounded(id) : null,
        grammars: withProfiles ? (p) async => 'root ::= "${p.id}"' : null,
      ),
    );
    addTearDown(o.dispose);
    await o.start();
    final id = expectOk(await o.enqueue(recordingId));
    await o.whenIdle();
    return id;
  }
}

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
  });

  group('ExtractStep with profile grammar (LLM-05 wiring)', () {
    test('the profile grammar constrains decoding; a schema-valid answer is '
        'stored valid with the profile version', () async {
      final r = _Run(db, paths);
      final id = await r.run('r1');
      expect((await loadJob(db, id)).state, JobState.done);
      final request = r.llm.requests.single;
      expect(request.grammar, 'root ::= "meeting"');
      // Integration W3: PRF-02 prompts replace FND-11's interim prompt.
      expect(request.systemPrompt, startsWith(kExtractionSystemPrompt));
      expect(request.systemPrompt, contains('Instructions:'));
      expect(request.prompt, contains('Metadata:'));
      expect(request.prompt, contains('<transcript>\n[00:00:00] chunk_0'));
      final ext = expectOk(
        await db.extractionsRepository.get(extractionIdFor(id)),
      );
      expect(ext.valid, isTrue);
      expect(ext.json['title'], 'Release sync');
      expect(ext.profileVersion, _builtins['meeting']!.version);
    });

    test('regression: Meeting action items (`task` key) reach the '
        'action_items table with owner and evidence time', () async {
      final r = _Run(db, paths);
      await r.run('r1');
      final items = await db.select(db.actionItems).get();
      expect(items, hasLength(1));
      expect(items.single.body, 'Send notes');
      expect(items.single.owner, 'Ana');
      expect(items.single.tMs, 0);
      expect(
        actionItemsOf({
          'action_items': [
            'Plain',
            {'text': 'Old', 't': '01:02:03', 'due_iso': '2026-10-16'},
            {'owner': 'no text'},
            7,
          ],
        }),
        [
          (text: 'Plain', owner: null, dueIso: null, tMs: null),
          (text: 'Old', owner: null, dueIso: '2026-10-16', tMs: 3723000),
        ],
      );
    });

    test('an extraction strategy (LLM-06 seam) runs first; null falls '
        'through to the single pass', () async {
      final strategy = _Strategy(
        const ExtractedData(
          json: {'title': 'Long', 'summary': 's'},
          valid: true,
        ),
      );
      final llm = ScriptedLlm(output: jsonEncode(_validMeeting));
      Future<String> run(String rec) async {
        final o = PipelineOrchestrator.withEngines(
          db: db,
          paths: paths,
          engines: PipelineEngines(
            stt: ScriptedStt(),
            llm: llm,
            vault: FakeVaultWriter(),
            profiles: (id) async => _ungrounded(id),
            grammars: (_) async => 'root ::= x',
            extraction: strategy,
            activeModel: (_) async => 'llm-x',
          ),
        );
        addTearDown(o.dispose);
        await o.start();
        final id = expectOk(await o.enqueue(rec));
        await o.whenIdle();
        return id;
      }

      final id = await run('r1');
      expect(strategy.calls, 1);
      // Integration W3: the strategy gets the step's resolved model id.
      expect(strategy.modelIds, ['llm-x']);
      expect(llm.requests, isEmpty);
      final ext = expectOk(
        await db.extractionsRepository.get(extractionIdFor(id)),
      );
      expect(ext.json['title'], 'Long');

      strategy.result = null;
      await seedRecordingWithChunks(db, 'r2', chunks: 1);
      await run('r2');
      expect(strategy.calls, 2);
      expect(llm.requests, hasLength(1));
    });

    test('invalid output is repaired once, then falls back to a free-text '
        'summary (valid = false, first line = title)', () async {
      final llm = _SequenceLlm([
        '{"title": 1}',
        'not json',
        'Fallback title\nTwo sentences of summary.',
      ]);
      final r = _Run(db, paths, llm: ScriptedLlm());
      final o = PipelineOrchestrator.withEngines(
        db: db,
        paths: paths,
        engines: PipelineEngines(
          stt: r.stt,
          llm: llm,
          vault: r.vault,
          profiles: (id) async => _ungrounded(id),
          grammars: (_) async => 'root ::= x',
        ),
      );
      addTearDown(o.dispose);
      await o.start();
      final id = expectOk(await o.enqueue('r1'));
      await o.whenIdle();
      expect(llm.requests, hasLength(3));
      expect(llm.requests[1].sampling.preset, LlmPreset.deterministic);
      expect(llm.requests[2].grammar, isNull, reason: 'summary is free text');
      final ext = expectOk(
        await db.extractionsRepository.get(extractionIdFor(id)),
      );
      expect(ext.valid, isFalse);
      expect(ext.json, {
        'title': 'Fallback title',
        'summary': 'Two sentences of summary.',
      });
    });

    test('without a profile resolver the FND-05 placeholder prompt runs '
        'unconstrained', () async {
      final r = _Run(db, paths, withProfiles: false);
      await r.run('r1');
      expect(r.llm.requests.single.grammar, isNull);
    });
  });

  group('WriteStep with filename patterns and planExport (EXP-02 wiring)', () {
    test("the profile's own pattern names the note", () async {
      final r = _Run(db, paths);
      await r.run('r1');
      expect(r.vault.notes.keys, ['${_date(t0)}-Meeting-release-sync.md']);
    });

    test('the setting pattern applies when the profile has none; an invalid '
        'setting falls back to the default', () async {
      expectOk(
        await db.settingsRepository.set(
          SettingKeys.exportFilenamePattern,
          'Notes/{{id}}.md',
        ),
      );
      final r = _Run(db, paths, withProfiles: false);
      await r.run('r1');
      expect(r.vault.notes.keys, ['Notes/r1.md']);

      await seedRecordingWithChunks(db, 'r2', chunks: 1);
      expectOk(
        await db.settingsRepository.set(
          SettingKeys.exportFilenamePattern,
          '/bad',
        ),
      );
      final r2 = _Run(db, paths, withProfiles: false);
      await r2.run('r2');
      expect(r2.vault.notes.keys, ['${_date(t0)}-meeting-release-sync.md']);
    });

    test(
      'a foreign file at the path is never replaced: suffix (default)',
      () async {
        final r = _Run(db, paths);
        final name = '${_date(t0)}-Meeting-release-sync.md';
        r.vault.notes[name] = 'user note';
        await r.run('r1');
        expect(r.vault.notes[name], 'user note');
        final suffixed = '${_date(t0)}-Meeting-release-sync-2.md';
        expect(r.vault.notes[suffixed], contains('Release sync'));
        final export = (await db.select(db.exports).get()).single;
        expect(export.relPath, suffixed);
        expect(export.status, ExportStatus.written);
      },
    );

    test('skip mode leaves a taken path alone and records no export', () async {
      expectOk(
        await db.settingsRepository.set(
          SettingKeys.exportCollisionMode,
          'skip',
        ),
      );
      final r = _Run(db, paths);
      final name = '${_date(t0)}-Meeting-release-sync.md';
      r.vault.notes[name] = 'user note';
      final id = await r.run('r1');
      expect((await loadJob(db, id)).state, JobState.done);
      expect(r.vault.notes, {name: 'user note'});
      expect(await db.select(db.exports).get(), isEmpty);
    });

    test('a vault write failure fails the step (retryable)', () async {
      final r = _Run(db, paths)..vault.access = VaultAccess.unavailable;
      final id = await r.run('r1');
      final job = await loadJob(db, id);
      expect(job.step, PipelineStepId.write);
      expect(job.state, isNot(JobState.done));
    });
  });
}

class _Strategy implements ExtractionStrategy {
  _Strategy(this.result);

  ExtractedData? result;
  int calls = 0;
  final List<String> modelIds = [];

  @override
  Future<Result<ExtractedData>?> extract(
    StepContext ctx, {
    required Profile profile,
    required String grammar,
    required List<TranscriptSegmentRow> segments,
    required int maxTokens,
    required String modelId,
    PromptMetadata? metadata,
  }) async {
    calls++;
    modelIds.add(modelId);
    final r = result;
    return r == null ? null : Ok(r);
  }
}

/// Returns [outputs] in order (last one repeated).
class _SequenceLlm extends ScriptedLlm {
  _SequenceLlm(this.outputs);

  final List<String> outputs;

  @override
  String get output =>
      outputs[(requests.length - 1).clamp(0, outputs.length - 1)];
}
