import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/classification_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

final BuiltinProfiles _builtins = BuiltinProfiles.parse({
  for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
});

/// Answers classification requests (grammar with a `profile` enum) with
/// [classification] and extraction requests with a minimal valid JSON.
class _Llm implements LlmEngine {
  _Llm(this.classification);

  String classification;
  final List<LlmRequest> requests = [];

  /// Grammars of the extraction requests (the summary fallback has none).
  List<String> get extractionGrammars => [
    for (final r in requests)
      if (r.sampling.preset != LlmPreset.classification && r.grammar != null)
        r.grammar!,
  ];

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    requests.add(request);
    final isClassification =
        request.sampling.preset == LlmPreset.classification;
    return Ok(
      isClassification
          ? classification
          : jsonEncode({'title': 't', 'summary': 's'}),
    );
  }
}

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;
  late _Llm llm;
  late PipelineOrchestrator o;

  Future<String> enqueue({String? profileId}) async {
    await o.start();
    final id = expectOk(await o.enqueue('r1', profileId: profileId));
    await o.whenIdle();
    return id;
  }

  Future<String?> recordingProfile() async =>
      expectOk(await db.recordingsRepository.get('r1')).profileId;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
    llm = _Llm('{"profile":"warranty","confidence":0.9}');
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: ScriptedStt(),
        llm: llm,
        vault: FakeVaultWriter(),
        profiles: (id) async => _builtins[id],
        profileList: () async => _builtins.all.toList(),
        grammars: (p) async => 'root ::= "${p.id}"',
      ),
    );
    addTearDown(o.dispose);
  });

  group('[PRF-06/AC1] Auto selects the profile before extraction', () {
    test('a confident answer is stored on the recording and drives '
        'extraction', () async {
      final id = await enqueue();
      expect((await loadJob(db, id)).state, JobState.done);
      expect(await recordingProfile(), 'warranty');
      expect(llm.requests.first.sampling.preset, LlmPreset.classification);
      expect(llm.extractionGrammars.last, 'root ::= "warranty"');
      final stored = expectOk(
        await db.settingsRepository.get(ClassificationKeys.result('r1')),
      );
      expect(stored, containsPair('profile', 'warranty'));
      expect(stored, isNot(contains('transcript')));
    });

    test('a recording with a chosen profile is not classified', () async {
      await db.recordingsRepository.updateFields(
        'r1',
        const RecordingsCompanion(profileId: Value('meeting')),
      );
      final id = await enqueue();
      expect((await loadJob(db, id)).state, JobState.done);
      expect(
        llm.requests.where(
          (r) => r.sampling.preset == LlmPreset.classification,
        ),
        isEmpty,
      );
      expect(await recordingProfile(), 'meeting');
    });

    test(
      'without a profile list the step is skipped (default profile)',
      () async {
        final plain = PipelineOrchestrator.withEngines(
          db: db,
          paths: paths,
          engines: PipelineEngines(
            stt: ScriptedStt(),
            llm: llm,
            vault: FakeVaultWriter(),
            profiles: (id) async => _builtins[id],
            grammars: (p) async => 'root ::= "${p.id}"',
          ),
        );
        addTearDown(plain.dispose);
        await plain.start();
        final id = expectOk(await plain.enqueue('r1'));
        await plain.whenIdle();
        expect((await loadJob(db, id)).state, JobState.done);
        expect(await recordingProfile(), isNull);
        expect(llm.extractionGrammars, everyElement('root ::= "meeting"'));
        expect(llm.extractionGrammars, isNotEmpty);
      },
    );
  });

  group(
    '[PRF-06/AC2] low confidence still continues, the user can change it',
    () {
      test('below 0.6 the best guess is used and the job finishes', () async {
        llm.classification = '{"profile":"engineering","confidence":0.4}';
        final id = await enqueue();
        expect((await loadJob(db, id)).state, JobState.done);
        expect(await recordingProfile(), 'engineering');
        final stored = expectOk(
          await db.settingsRepository.get(ClassificationKeys.result('r1')),
        );
        expect(stored, containsPair('profile', 'engineering'));
        expect(stored, containsPair('confidence', 0.4));
        expect(
          llm.requests.where(
            (r) => r.sampling.preset == LlmPreset.classification,
          ),
          hasLength(1),
        );
      });

      test(
        'the user changes the profile: re-run from extract with it',
        () async {
          llm.classification = '{"profile":"engineering","confidence":0.4}';
          final id = await enqueue();
          expectOk(
            await o.rerun(id, PipelineStepId.extract, profileId: 'meeting'),
          );
          await o.whenIdle();
          expect((await loadJob(db, id)).state, JobState.done);
          expect(await recordingProfile(), 'meeting');
          expect(llm.extractionGrammars.last, 'root ::= "meeting"');
        },
      );
    },
  );

  group('[PRF-06/scope] override after the fact re-runs extraction', () {
    test(
      'changing the profile of a finished note re-extracts with it',
      () async {
        final id = await enqueue();
        expect(await recordingProfile(), 'warranty');
        expectOk(
          await o.rerun(id, PipelineStepId.extract, profileId: 'engineering'),
        );
        await o.whenIdle();
        expect((await loadJob(db, id)).state, JobState.done);
        expect(await recordingProfile(), 'engineering');
        expect(llm.extractionGrammars.last, 'root ::= "engineering"');
        // Classification is not repeated.
        expect(
          llm.requests.where(
            (r) => r.sampling.preset == LlmPreset.classification,
          ),
          hasLength(1),
        );
      },
    );
  });
}
