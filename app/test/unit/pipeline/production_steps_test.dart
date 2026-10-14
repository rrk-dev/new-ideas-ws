import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/extract_step.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

final BuiltinProfiles _builtins = BuiltinProfiles.parse({
  for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
});

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
        profiles: withProfiles ? (id) async => _builtins[id] : null,
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
      expect(request.systemPrompt, kInterimExtractionSystemPrompt);
      expect(request.prompt, contains('<transcript>\n[00:00:00] chunk_0'));
      final ext = expectOk(
        await db.extractionsRepository.get(extractionIdFor(id)),
      );
      expect(ext.valid, isTrue);
      expect(ext.json['title'], 'Release sync');
      expect(ext.profileVersion, _builtins['meeting']!.version);
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
          profiles: (id) async => _builtins[id],
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

/// Returns [outputs] in order (last one repeated).
class _SequenceLlm extends ScriptedLlm {
  _SequenceLlm(this.outputs);

  final List<String> outputs;

  @override
  String get output =>
      outputs[(requests.length - 1).clamp(0, outputs.length - 1)];
}
