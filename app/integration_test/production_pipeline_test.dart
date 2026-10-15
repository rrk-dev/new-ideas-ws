import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/features/pipeline/data/engine_providers.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:yaml/yaml.dart';

/// Directory on the device holding `ggml-tiny.en.bin`,
/// `SmolLM2-135M-Instruct-Q8_0.gguf` and `jfk.wav` from
/// `tools/ci/fetch_test_models.sh` (push them, then pass
/// `--dart-define=VV_TEST_MODELS_DIR=<device path>`).
const String kTestModelsDir = String.fromEnvironment('VV_TEST_MODELS_DIR');

/// FND-11 on a device: the production providers (real platform paths, the
/// app-local vault host API) run a recording through the pipeline worker
/// with the real tiny models. Device rows: docs/test-plans/device/FND-11.md.
///   cd app && fvm flutter test integration_test/production_pipeline_test.dart \
///     --flavor dev -d DEVICE --dart-define=VV_TEST_MODELS_DIR=DIR
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = kTestModelsDir.isEmpty ? 'pass VV_TEST_MODELS_DIR' : null;

  Future<void> install(
    VaultVoiceDatabase db,
    String modelsDir,
    String root, {
    required String id,
    required ModelType type,
    required String file,
  }) async {
    final target = File(p.join(modelsDir, id, file));
    await target.parent.create(recursive: true);
    await File(p.join(kTestModelsDir, file)).copy(target.path);
    await db.modelsRepository.upsert(
      ModelsInstalledCompanion.insert(
        id: id,
        type: type,
        version: '1',
        path: p.relative(target.path, from: root),
        sha256: '0' * 64,
        size: target.lengthSync(),
        installedAt: DateTime.now(),
      ),
    );
  }

  testWidgets(
    '[FND-11/AC4] a recording becomes a note in the app-local vault on the '
    'device with the real tiny models',
    skip: skip != null,
    (tester) async {
      final appPaths = await AppPaths.resolve();
      final container = ProviderContainer(
        overrides: [appPathsProvider.overrideWithValue(appPaths)],
      );
      addTearDown(container.dispose);
      final db = container.read(vaultVoiceDatabaseProvider);
      final paths = await container.read(storagePathsProvider.future);
      final rec = 'fnd11-${DateTime.now().millisecondsSinceEpoch}';

      await tester.runAsync(() async {
        final chunk = p.join(paths.audioDir(rec), 'chunk_0.wav');
        await Directory(p.dirname(chunk)).create(recursive: true);
        await File(p.join(kTestModelsDir, 'jfk.wav')).copy(chunk);
        await db.recordingsRepository.create(
          RecordingsCompanion.insert(
            id: rec,
            createdAt: DateTime.now().toUtc(),
            status: RecordingStatus.recorded,
            source: RecordingSource.imported,
          ),
        );
        await db.recordingsRepository.upsertChunk(
          AudioChunksCompanion.insert(
            recordingId: rec,
            seq: 0,
            path: paths.relativize(chunk),
            sampleRate: 16000,
            startMs: 0,
            endMs: 11000,
            bytes: File(chunk).lengthSync(),
          ),
        );
        if ((await db.vaultRepository.watchTargets().first).isEmpty) {
          await db.vaultRepository.upsertTarget(
            VaultTargetsCompanion.insert(
              id: 'local',
              platform: VaultPlatform.appLocal,
              displayName: 'On this device',
              handle: 'app-local',
              createdAt: DateTime.now().toUtc(),
            ),
          );
        }
        await install(
          db,
          paths.modelsDir,
          paths.root,
          id: 'whisper-tiny.en',
          type: ModelType.stt,
          file: 'ggml-tiny.en.bin',
        );
        await install(
          db,
          paths.modelsDir,
          paths.root,
          id: 'smollm2-135m',
          type: ModelType.llm,
          file: 'SmolLM2-135M-Instruct-Q8_0.gguf',
        );

        final client = await container.read(pipelineClientProvider.future);
        final jobId = (await client.enqueue(
          rec,
          userInitiated: true,
        )).valueOrNull!;
        final sw = Stopwatch()..start();
        while (true) {
          final job = jobFromRow(
            (await db.jobsRepository.get(jobId)).valueOrNull!,
          );
          if (job.state == JobState.done) break;
          expect(job.state, isNot(JobState.failed), reason: job.errorDetail);
          if (sw.elapsed > const Duration(minutes: 10)) fail('timed out');
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }

        final export =
            (await db.vaultRepository.watchExports(recordingId: rec).first)
                .single;
        expect(export.status, ExportStatus.written);
        final vault = await container.read(appLocalVaultRootProvider.future);
        final markdown = File(p.join(vault, export.relPath)).readAsStringSync();
        final end = markdown.indexOf('\n---\n', 4);
        expect(markdown, startsWith('---\n'));
        final front = loadYaml(markdown.substring(4, end)) as YamlMap;
        expect(front['source'], 'vaultvoice');
        expect(front['recording_id'], rec);
      });
    },
  );
}
