import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

import '../../db/db_test_utils.dart';

/// Polls [condition] (real time) until true or fails after [timeout].
Future<void> until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed > timeout) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Future<void> _blockUntil(CancelToken? cancel, Completer<void>? release) async {
  while (!(cancel?.isCancelled ?? false) && !(release?.isCompleted ?? false)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// STT returning one segment per chunk (`chunk_<n>`). Call [blockOn] (0-based
/// call index) hangs until cancelled or [release] completes; [failures] are
/// returned for the first calls.
class ScriptedStt implements SttEngine {
  ScriptedStt({this.blockOn, this.ignoreCancel = false});

  final List<String> calls = [];
  int? blockOn;
  bool ignoreCancel;
  final Completer<void> release = Completer();
  final List<Failure> failures = [];

  bool get blocked => blockOn != null && calls.length > blockOn!;

  @override
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
  }) async {
    calls.add(audioPath);
    if (calls.length - 1 == blockOn) {
      await _blockUntil(ignoreCancel ? null : cancel, release);
      if (!ignoreCancel && (cancel?.isCancelled ?? false)) {
        return const Err(CancelledFailure());
      }
    }
    if (failures.isNotEmpty) return Err(failures.removeAt(0));
    onProgress?.call(0.5);
    onProgress?.call(1);
    return Ok(
      Transcript([
        TranscriptSegment(
          start: Duration.zero,
          end: const Duration(seconds: 1),
          text: p.basenameWithoutExtension(audioPath),
        ),
      ]),
    );
  }
}

/// LLM returning [output]; [failures] are returned first; call [blockOn]
/// hangs until [release] (cancellation is ignored when [ignoreCancel]).
class ScriptedLlm implements LlmEngine {
  ScriptedLlm({this.output = '{"summary":"ok","action_items":["Send notes"]}'});

  String output;
  final List<LlmRequest> requests = [];
  final List<Failure> failures = [];
  int? blockOn;
  bool ignoreCancel = false;
  final Completer<void> release = Completer();

  bool get blocked => blockOn != null && requests.length > blockOn!;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    requests.add(request);
    if (requests.length - 1 == blockOn) {
      await _blockUntil(ignoreCancel ? null : cancel, release);
      if (!ignoreCancel && (cancel?.isCancelled ?? false)) {
        return const Err(CancelledFailure());
      }
    }
    if (failures.isNotEmpty) return Err(failures.removeAt(0));
    onToken?.call(output);
    return Ok(output);
  }
}

/// A recording with [chunks] audio chunks of 30 s each.
Future<void> seedRecordingWithChunks(
  VaultVoiceDatabase db,
  String id, {
  int chunks = 3,
}) async {
  await seedRecording(db, id);
  for (var seq = 0; seq < chunks; seq++) {
    expectOk(
      await db.recordingsRepository.upsertChunk(
        AudioChunksCompanion.insert(
          recordingId: id,
          seq: seq,
          path: p.join('audio', id, 'chunk_$seq.wav'),
          sampleRate: 16000,
          startMs: seq * 30000,
          endMs: (seq + 1) * 30000,
          bytes: 1,
        ),
      ),
    );
  }
}

Future<void> seedVaultTarget(VaultVoiceDatabase db, [String id = 'v1']) async {
  expectOk(
    await db.vaultRepository.upsertTarget(
      VaultTargetsCompanion.insert(
        id: id,
        platform: VaultPlatform.androidSaf,
        displayName: 'Vault',
        handle: 'content://tree/$id',
        createdAt: t0,
      ),
    ),
  );
}

Future<JobSnapshot> loadJob(VaultVoiceDatabase db, String id) async =>
    jobFromRow(expectOk(await db.jobsRepository.get(id)));

/// A temp storage root removed at teardown.
StoragePaths tempPaths() {
  final dir = Directory.systemTemp.createTempSync('vv_pipeline_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return StoragePaths(p.join(dir.path, 'vv'));
}

/// Sequential ids j1, j2, …
String Function() sequentialIds() {
  var n = 0;
  return () => 'j${++n}';
}
