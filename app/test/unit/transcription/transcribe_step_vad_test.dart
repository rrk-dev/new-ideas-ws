import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/transcribe_step.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_stt_engine.dart';
import '../pipeline/pipeline_test_utils.dart';

class _Ctx implements StepContext {
  _Ctx(this.db, this.job);

  final VaultVoiceDatabase db;
  @override
  final JobSnapshot job;
  @override
  final CancelToken cancel = CancelToken();
  Map<String, Object?>? lastCheckpoint;

  @override
  void reportProgress(double fraction) {}

  @override
  Future<void> saveCheckpoint(
    Map<String, Object?> checkpoint, {
    double? progress,
    Future<void> Function()? writes,
  }) async {
    lastCheckpoint = checkpoint;
    await db.transaction(() async => await writes?.call());
  }
}

class _Vad implements VadEngine {
  _Vad({this.fail = false});

  final bool fail;
  final calls = <(String, String)>[];

  @override
  Future<Result<List<SpeechSpan>>> speechSegments(
    String modelPath,
    String wavPath,
  ) async {
    calls.add((modelPath, wavPath));
    if (fail) return const Err(UnexpectedFailure('vad'));
    return const Ok([SpeechSpan(500, 4000), SpeechSpan(9000, 12000)]);
  }

  @override
  Future<void> dispose() async {}
}

JobSnapshot _job() => JobSnapshot(
  id: 'j1',
  recordingId: 'r1',
  state: JobState.transcribing,
  step: PipelineStepId.transcribe,
  createdAt: t0,
  updatedAt: t0,
);

void main() {
  late Directory dir;
  late StoragePaths paths;
  late VaultVoiceDatabase db;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('vv_vad_step_');
    paths = StoragePaths(dir.path);
    db = memoryDb();
    await seedRecordingWithChunks(db, 'r1', chunks: 2);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> installVad() async {
    final rel = p.join('models', 'silero', 'ggml-silero-v6.2.0.bin');
    File(paths.resolve(rel))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [0]);
    expectOk(
      await db.modelsRepository.upsert(
        ModelsInstalledCompanion.insert(
          id: 'silero-vad-v6.2.0',
          type: ModelType.vad,
          version: '1',
          path: rel,
          sha256: 'x',
          size: 1,
          installedAt: t0,
        ),
      ),
    );
    return paths.resolve(rel);
  }

  Future<List<SpeechSegmentRow>> speech() =>
      db.recordingsRepository.watchSpeechSegments('r1').first;

  test('[AUD-03] with the VAD model installed, STT skips silence '
      '(VAD model passed to whisper) and the speech timeline is stored on the '
      'recording timeline', () async {
    final model = await installVad();
    final stt = FakeSttEngine();
    final vad = _Vad();
    final step = TranscribeStep(
      db: db,
      paths: paths,
      stt: stt,
      config: const PipelineConfig(),
      vad: vad,
    );
    expect(await step.run(_Ctx(db, _job())), isA<StepSucceeded>());
    expect(stt.lastOptions?.vadModelPath, model);
    expect(vad.calls.map((c) => c.$1), [model, model]);
    final rows = await speech();
    expect(
      [for (final r in rows) (r.startMs, r.endMs)],
      [
        (500, 4000),
        (9000, 12000),
        (30500, 34000), // chunk 1 starts at 30 s
        (39000, 42000),
      ],
    );

    // Re-run from scratch replaces (not duplicates) the timeline.
    expect(await step.run(_Ctx(db, _job())), isA<StepSucceeded>());
    expect(await speech(), hasLength(4));
  });

  test('skip silence off / no model: no VAD, no timeline; the params hash '
      'differs so a resume never mixes both modes', () async {
    final stt = FakeSttEngine();
    final vad = _Vad();
    final step = TranscribeStep(
      db: db,
      paths: paths,
      stt: stt,
      config: const PipelineConfig(),
      vad: vad,
    );
    final noModel = _Ctx(db, _job());
    await step.run(noModel);
    expect(stt.lastOptions?.vadModelPath, isNull);
    expect(vad.calls, isEmpty);
    expect(await speech(), isEmpty);

    await installVad();
    final withModel = _Ctx(db, _job());
    await step.run(withModel);
    expect(
      withModel.lastCheckpoint!['paramsHash'],
      isNot(noModel.lastCheckpoint!['paramsHash']),
    );

    expectOk(
      await db.settingsRepository.set(SettingKeys.processingSkipSilence, false),
    );
    await step.run(_Ctx(db, _job()));
    expect(stt.lastOptions?.vadModelPath, isNull);
  });

  test('a VAD failure loses only the timeline, never the transcript', () async {
    await installVad();
    final step = TranscribeStep(
      db: db,
      paths: paths,
      stt: FakeSttEngine(),
      config: const PipelineConfig(),
      vad: _Vad(fail: true),
    );
    expect(await step.run(_Ctx(db, _job())), isA<StepSucceeded>());
    expect(await speech(), isEmpty);
  });
}
