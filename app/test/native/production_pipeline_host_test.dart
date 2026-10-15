@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 8))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:yaml/yaml.dart';

/// FND-11 end to end on the host with the real engines: the production
/// providers spawn the pipeline worker, which builds whisper.cpp + llama.cpp
/// engines over the installed test models (`ggml-tiny.en`, SmolLM2-135M),
/// grammar-constrained extraction with the built-in Meeting profile, the
/// Mustache renderer and the app-local vault writer.
///
/// Needs `native/build.sh host` and
/// `tools/ci/fetch_test_models.sh` (models dir: `$VV_TEST_MODELS_DIR` or the
/// default cache); skipped otherwise.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String _modelsDir() =>
    Platform.environment['VV_TEST_MODELS_DIR'] ??
    '${Platform.environment['HOME']}/.cache/vaultvoice/test-models';

const _sttFile = 'ggml-tiny.en.bin';
const _llmFile = 'SmolLM2-135M-Instruct-Q8_0.gguf';

/// Installs [file] from the test-models cache like MDL-02 does: a file under
/// `models/<id>/` (a symlink — no 200 MB copies) plus its `models_installed`
/// row.
Future<void> _install(
  VaultVoiceDatabase db,
  StoragePaths paths, {
  required String id,
  required ModelType type,
  required String file,
}) async {
  final source = File(p.join(_modelsDir(), file));
  final target = p.join(paths.modelsDir, id, file);
  await Directory(p.dirname(target)).create(recursive: true);
  await Link(target).create(source.absolute.path);
  await db.modelsRepository.upsert(
    ModelsInstalledCompanion.insert(
      id: id,
      type: type,
      version: '1',
      path: paths.relativize(target),
      sha256: '0' * 64,
      size: source.lengthSync(),
      installedAt: DateTime.now(),
    ),
  );
}

Future<JobSnapshot> _waitFor(
  VaultVoiceDatabase db,
  String jobId,
  bool Function(JobSnapshot job) done, {
  Duration timeout = const Duration(minutes: 6),
}) async {
  final sw = Stopwatch()..start();
  while (true) {
    final job = jobFromRow((await db.jobsRepository.get(jobId)).valueOrNull!);
    if (done(job)) return job;
    if (job.state == JobState.failed) {
      fail('job failed: ${job.errorDetail} at ${job.step.name}');
    }
    if (sw.elapsed > timeout) fail('timed out in ${job.state.name}');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  final lib = _hostLib();
  final wav = File(p.join(_modelsDir(), 'jfk.wav'));
  final skip = lib == null
      ? 'run native/build.sh host first'
      : !File(p.join(_modelsDir(), _sttFile)).existsSync() ||
            !File(p.join(_modelsDir(), _llmFile)).existsSync() ||
            !wav.existsSync()
      ? 'run tools/ci/fetch_test_models.sh'
      : null;

  test(
    '[FND-11/AC2] [FND-11/AC3] a recording becomes one note in the app-local '
    'vault through the production worker with the real tiny models; '
    'without models it waits instead of failing',
    skip: skip,
    () async {
      final tmp = Directory.systemTemp.createTempSync('vv_fnd11_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final paths = StoragePaths(p.join(tmp.path, 'vv'));
      final appPaths = AppPaths(
        root: Directory(paths.root),
        temp: Directory(p.join(tmp.path, 'tmp')),
      );
      final container = ProviderContainer(
        overrides: [
          storagePathsProvider.overrideWith((ref) async => paths),
          appPathsProvider.overrideWithValue(appPaths),
          nativeLibraryPathProvider.overrideWithValue(lib),
        ],
      );
      addTearDown(container.dispose);
      final db = container.read(vaultVoiceDatabaseProvider);

      // A finished 11 s recording (one 16 kHz mono chunk).
      const rec = 'rec-jfk';
      final chunk = p.join(paths.audioDir(rec), 'chunk_0.wav');
      await Directory(p.dirname(chunk)).create(recursive: true);
      await wav.copy(chunk);
      await db.recordingsRepository.create(
        RecordingsCompanion.insert(
          id: rec,
          createdAt: DateTime.utc(2026, 10, 14, 9),
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
          bytes: wav.lengthSync(),
        ),
      );
      // The configured target: the app's own vault folder.
      await db.vaultRepository.upsertTarget(
        VaultTargetsCompanion.insert(
          id: 'local',
          platform: VaultPlatform.appLocal,
          displayName: 'On this device',
          handle: 'app-local',
          createdAt: DateTime.utc(2026, 10, 14),
        ),
      );

      final client = await container.read(pipelineClientProvider.future);
      final jobId = (await client.enqueue(
        rec,
        userInitiated: true,
      )).valueOrNull!;

      // AC3: no model installed → waiting(model_missing), not failed.
      final waiting = await _waitFor(
        db,
        jobId,
        (j) => j.state == JobState.waiting,
        timeout: const Duration(seconds: 30),
      );
      expect(waiting.waitingReason, WaitingReason.modelMissing);
      expect(waiting.step, PipelineStepId.transcribe);
      expect(await db.select(db.transcriptSegments).get(), isEmpty);

      // Installing the models resumes the job (publisher → resolveWaiting).
      await _install(
        db,
        paths,
        id: 'whisper-tiny.en',
        type: ModelType.stt,
        file: _sttFile,
      );
      await _install(
        db,
        paths,
        id: 'smollm2-135m',
        type: ModelType.llm,
        file: _llmFile,
      );
      await _waitFor(db, jobId, (j) => j.state == JobState.done);

      // Transcript from whisper.cpp.
      final segments = await db.select(db.transcriptSegments).get();
      expect(
        segments.map((s) => s.body).join(' ').toLowerCase(),
        contains('country'),
      );
      final transcript = (await db.select(db.transcripts).get()).single;
      expect(transcript.modelId, 'whisper-tiny.en');
      final extraction = (await db.select(db.extractions).get()).single;
      expect(extraction.modelId, 'smollm2-135m');
      expect(extraction.profileId, 'meeting');

      // Exactly one note in the app-local vault, with valid front-matter.
      final vault = Directory(p.join(paths.root, 'vault'));
      final notes = vault
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(notes, hasLength(1));
      final markdown = notes.single.readAsStringSync();
      expect(markdown, startsWith('---\n'));
      final end = markdown.indexOf('\n---\n', 4);
      expect(end, greaterThan(0), reason: 'front-matter is closed');
      final front = loadYaml(markdown.substring(4, end)) as YamlMap;
      expect(front['source'], 'vaultvoice');
      expect(front['recording_id'], rec);
      expect('${front['title'] ?? ''}'.trim(), isNotEmpty);

      final exports = await db.select(db.exports).get();
      expect(exports, hasLength(1));
      expect(exports.single.status, ExportStatus.written);
      expect(p.join(vault.path, exports.single.relPath), notes.single.path);

      // FND-07 metrics of the heavy steps.
      final metrics = [
        for (final line in appPaths.metricsFile.readAsLinesSync())
          if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, Object?>,
      ];
      final stt = metrics.singleWhere((m) => m['step'] == 'transcribe');
      expect(stt['audio_ms'], 11000);
      expect(stt['wall_ms']! as num, greaterThan(0));
      final llm = metrics.singleWhere((m) => m['step'] == 'extract');
      expect(llm['gen_tokens']! as num, greaterThan(0));
      expect(llm['prompt_tokens']! as num, greaterThan(0));
    },
  );
}
