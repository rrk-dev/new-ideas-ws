import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/diagnostics/job_metrics.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/data/active_models_publisher.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/data/production_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/extract_step.dart';
import 'package:vaultvoice/features/pipeline/data/steps/transcribe_step.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_llm_runtime.dart';
import 'pipeline_test_utils.dart';

FeatureAccess _personal() => FeatureAccess.resolve(
  Entitlement.free(t0),
  now: t0,
  mode: DistributionMode.personal,
);

Future<String> _install(
  VaultVoiceDatabase db,
  StoragePaths paths,
  String id,
  ModelType type, {
  bool file = true,
  String? storedPath,
}) async {
  final f = File(p.join(paths.modelsDir, id, '$id.bin'));
  if (file) {
    await f.parent.create(recursive: true);
    await f.writeAsString('x');
  }
  expectOk(
    await db.modelsRepository.upsert(
      ModelsInstalledCompanion.insert(
        id: id,
        type: type,
        version: '1',
        path: storedPath ?? paths.relativize(f.path),
        sha256: '0' * 64,
        size: 1,
        installedAt: t0,
      ),
    ),
  );
  return f.path;
}

Future<void> _publish(VaultVoiceDatabase db, ActiveModelSelection s) async {
  expectOk(await db.settingsRepository.set(kActiveModelsKey, s.toJson()));
}

/// Records `resolveWaiting` calls.
class _RecordingClient implements PipelineClient {
  final List<String> resolved = [];

  @override
  Future<Result<void>> resolveWaiting(String jobId) async {
    resolved.add(jobId);
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _seedJob(
  VaultVoiceDatabase db,
  String id,
  JobState state, {
  WaitingReason? reason,
}) async {
  await seedRecording(db, 'rec-$id');
  expectOk(
    await db.jobsRepository.create(
      jobToCompanion(
        JobSnapshot(
          id: id,
          recordingId: 'rec-$id',
          state: state,
          step: PipelineStepId.transcribe,
          waitingReason: reason,
          createdAt: t0,
          updatedAt: t0,
        ),
      ),
    ),
  );
}

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;

  setUp(() {
    db = memoryDb();
    paths = tempPaths();
  });

  group('InstalledModelResolver', () {
    test('resolves only a published, installed model of the right type '
        'whose file exists inside the storage root', () async {
      final r = InstalledModelResolver(db: db, paths: paths);
      expect(await r.resolve(HeavyModel.stt), isNull, reason: 'unpublished');

      await _publish(
        db,
        const ActiveModelSelection(stt: 's', llm: 'l', llmContext: 6144),
      );
      expect(await r.resolve(HeavyModel.stt), isNull, reason: 'no row');

      final path = await _install(db, paths, 's', ModelType.stt);
      await _install(db, paths, 'l', ModelType.stt); // wrong type
      final stt = (await r.resolve(HeavyModel.stt))!;
      expect(stt.id, 's');
      expect(stt.path, p.normalize(path));
      expect(stt.contextSize, 6144);
      expect(await r.activeId(HeavyModel.stt), 's');
      expect(await r.resolve(HeavyModel.llm), isNull, reason: 'type');

      await _install(
        db,
        paths,
        'l',
        ModelType.llm,
        file: false,
        storedPath: 'models/l/missing.bin',
      );
      expect(await r.resolve(HeavyModel.llm), isNull, reason: 'no file');
      await _install(db, paths, 'l', ModelType.llm, storedPath: '../x.bin');
      expect(await r.resolve(HeavyModel.llm), isNull, reason: 'escapes');
      await _install(db, paths, 'l', ModelType.llm, storedPath: '/abs.bin');
      expect(await r.resolve(HeavyModel.llm), isNull, reason: 'absolute');
    });
  });

  group('ActiveSttEngine', () {
    test('a missing model is ModelMissingFailure; a model change rebuilds '
        'the whisper engine; STT acquisition unloads the LLM', () async {
      ActiveModel? active;
      final created = <String>[];
      final residency = ModelResidency();
      var llmUnloads = 0;
      residency
        ..register(ResidentModel.llm, () => llmUnloads++)
        ..acquire(ResidentModel.llm);
      final stt = ActiveSttEngine(
        resolve: () async => active,
        residency: residency,
        create: (m) {
          created.add(m.id);
          return WhisperSttEngine(
            modelId: m.id,
            modelPath: () async => m.path, // not on disk: no FFI load
          );
        },
      );
      expect(
        (await stt.transcribe('a.wav')).failureOrNull,
        isA<ModelMissingFailure>(),
      );
      expect(created, isEmpty);

      active = const ActiveModel(id: 'a', path: '/nope/a.bin', sizeBytes: 1);
      expect(
        (await stt.transcribe('a.wav')).failureOrNull,
        isA<ModelMissingFailure>(),
      );
      await stt.transcribe('a.wav');
      expect(created, ['a'], reason: 'one engine per model');
      expect(stt.modelId, 'a');
      expect(llmUnloads, 1);
      expect(residency.loaded, {ResidentModel.stt});

      active = const ActiveModel(id: 'b', path: '/nope/b.bin', sizeBytes: 1);
      await stt.transcribe('a.wav');
      expect(created, ['a', 'b']);
      await stt.unload();
      expect(residency.loaded, isEmpty);
    });
  });

  group('ActiveLlmEngine', () {
    test('builds one LlmService per model/context, forwards lifecycle and '
        'memory pressure, and unloads STT before loading', () async {
      ActiveModel? active;
      final runtime = FakeLlmRuntime();
      final residency = ModelResidency();
      var sttUnloads = 0;
      residency
        ..register(ResidentModel.stt, () => sttUnloads++)
        ..acquire(ResidentModel.stt);
      final stats = LlmStatsTap();
      final llm = ActiveLlmEngine(
        resolve: () async => active,
        residency: residency,
        create: (m) => LlmService(
          runtime: runtime,
          modelPath: m.path,
          contextSize: m.contextSize,
          backend: () => const LlmBackendChoice(useGpu: false, reason: 't'),
          onBeforeLoad: () => residency.acquire(ResidentModel.llm),
          onStats: stats.add,
        ),
      );
      const request = LlmRequest(prompt: 'hi');
      expect(
        (await llm.generate(request)).failureOrNull,
        isA<ModelMissingFailure>(),
      );

      active = const ActiveModel(id: 'l', path: '/m/l.gguf', sizeBytes: 1);
      expect((await llm.generate(request)).valueOrNull, 'Hello!');
      expect(sttUnloads, 1, reason: 'never STT and LLM together');
      expect(residency.loaded, {ResidentModel.llm});
      expect(stats.take(), hasLength(1));
      expect(stats.take(), isEmpty);
      final first = llm.service;
      await llm.generate(request);
      expect(llm.service, same(first));

      llm.setForeground(foreground: false);
      active = const ActiveModel(
        id: 'l',
        path: '/m/l.gguf',
        sizeBytes: 1,
        contextSize: 8192,
      );
      await llm.generate(request);
      expect(llm.service, isNot(same(first)));
      expect(runtime.sessions.first.disposed, isTrue);
      llm
        ..setForeground(foreground: true)
        ..onMemoryPressure();
      expect(residency.loaded, isEmpty);
    });
  });

  group('PipelineJobMetrics', () {
    test('records audio duration for transcribe and summed LLM stats for '
        'extract; failed runs and light steps are not stored', () async {
      await seedRecordingWithChunks(db, 'r1', chunks: 2);
      final store = InMemoryMetricsStore();
      final stats = LlmStatsTap();
      final metrics = PipelineJobMetrics(
        db: db,
        sessions: JobMetricsRecorder(store: store, clock: FakeClock(t0)),
        llmStats: stats,
      );
      final job = JobSnapshot(
        id: 'j1',
        recordingId: 'r1',
        state: JobState.transcribing,
        step: PipelineStepId.transcribe,
        createdAt: t0,
        updatedAt: t0,
      );
      final transcribe = TranscribeStep(
        db: db,
        paths: paths,
        stt: ScriptedStt(),
        config: const PipelineConfig(),
      );
      final extract = ExtractStep(
        db: db,
        llm: ScriptedLlm(),
        config: const PipelineConfig(),
      );
      await (await metrics.begin(job, transcribe))!.finish(succeeded: true);

      final m = (await metrics.begin(job, extract))!;
      LlmRunStats run(int prompt, int gen) => LlmRunStats(
        status: LlmRunStatus.ok,
        nativeCode: 0,
        promptTokens: prompt,
        generatedTokens: gen,
        prefill: const Duration(milliseconds: 10),
        decode: const Duration(milliseconds: 20),
        usedGpu: false,
      );
      stats
        ..add(run(100, 10))
        ..add(run(50, 5));
      await m.finish(succeeded: true);
      await (await metrics.begin(job, extract))!.finish(succeeded: false);

      final all = await store.all();
      expect(all, hasLength(2));
      expect(all[0].step, 'transcribe');
      expect(all[0].audioDuration, const Duration(seconds: 60));
      expect(all[1].step, 'extract');
      expect(all[1].promptTokens, 150);
      expect(all[1].generatedTokens, 15);
      expect(all[1].decodeTime, const Duration(milliseconds: 40));

      final write = _LightStep();
      expect(await metrics.begin(job, write), isNull);
    });
  });

  group('ActiveModelsPublisher', () {
    test('publishes the selection once, tolerates failing catalog/device '
        'sources and serialises concurrent publishes', () async {
      var writes = 0;
      final sub = db.settingsRepository
          .watch(kActiveModelsKey)
          .listen((_) => writes++);
      addTearDown(sub.cancel);
      final publisher = ActiveModelsPublisher(
        settings: db.settingsRepository,
        models: db.modelsRepository,
        access: _personal,
        catalog: () async => throw StateError('offline'),
        device: () => throw StateError('no bridge'),
      );
      final none = await publisher.publish();
      expect(none, const ActiveModelSelection());
      await _install(db, paths, 'stt', ModelType.stt);
      await _install(db, paths, 'vad', ModelType.vad);
      final results = await Future.wait([
        publisher.publish(),
        publisher.publish(),
        publisher.publish(),
      ]);
      expect(results.last.stt, 'stt');
      expect(results.last.llm, isNull);
      final stored = expectOk(
        await db.settingsRepository.get(kActiveModelsKey),
      );
      expect(ActiveModelSelection.fromJson(stored).stt, 'stt');
      await pumpEventQueue();
      final before = writes;
      await publisher.publish(); // unchanged: no write
      await pumpEventQueue();
      expect(writes, before);
    });

    test('watch calls onAvailable when usable models change, honouring the '
        "user's preferred model", () async {
      final publisher = ActiveModelsPublisher(
        settings: db.settingsRepository,
        models: db.modelsRepository,
        access: _personal,
      );
      final seen = <ActiveModelSelection>[];
      final sub = publisher.watch(onAvailable: (s) async => seen.add(s));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen, isEmpty, reason: 'nothing installed');
      await _install(db, paths, 'llm-a', ModelType.llm);
      await until(() => seen.isNotEmpty);
      expect(seen.last.llm, 'llm-a');
      await _install(db, paths, 'llm-b', ModelType.llm);
      expectOk(await db.settingsRepository.set(kPreferredLlmModelKey, 'llm-b'));
      await until(() => seen.last.llm == 'llm-b');
    });

    test('resumeModelWaits resolves only jobs waiting for a model', () async {
      await _seedJob(
        db,
        'a',
        JobState.waiting,
        reason: WaitingReason.modelMissing,
      );
      await _seedJob(
        db,
        'b',
        JobState.waiting,
        reason: WaitingReason.destination,
      );
      await _seedJob(db, 'c', JobState.queued);
      final client = _RecordingClient();
      await resumeModelWaits(db.jobsRepository, client);
      expect(client.resolved, ['a']);
    });
  });
}

class _LightStep implements PipelineStep {
  @override
  PipelineStepId get id => PipelineStepId.write;

  @override
  HeavyModel? get model => null;

  @override
  bool canRun(JobSnapshot job) => true;

  @override
  Future<StepResult> run(StepContext ctx) async => const StepSucceeded();
}
