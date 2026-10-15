import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Transcribes the recording's audio chunks one by one, checkpointing after
/// every chunk (`{nextChunk, modelId, paramsHash}`). A resume skips finished
/// chunks only when the parameters hash matches; otherwise it starts over and
/// replaces the old segments.
///
/// AUD-03 silence skipping: when a VAD model is installed and
/// `processing.skip_silence` is on (default), whisper.cpp's built-in Silero
/// VAD skips silence inside each chunk (less compute, no hallucinated text on
/// silence; times stay on the original timeline) and, with a [vad] engine,
/// the chunk's speech spans are stored as `speech_segments` (recording
/// timeline) in the chunk's checkpoint transaction.
class TranscribeStep implements PipelineStep {
  TranscribeStep({
    required this.db,
    required this.paths,
    required this.stt,
    required this.config,
    this.clock = const SystemClock(),
    this.activeModel,
    this.vad,
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final SttEngine stt;
  final PipelineConfig config;
  final Clock clock;

  /// The active STT model (FND-11); null uses [PipelineConfig.sttModelId].
  final ActiveModelIdLookup? activeModel;
  /// Speech timeline (AUD-03); null = no `speech_segments` are written.
  final VadEngine? vad;

  @override
  PipelineStepId get id => PipelineStepId.transcribe;

  @override
  HeavyModel get model => HeavyModel.stt;

  @override
  bool canRun(JobSnapshot job) => true;

  String _paramsHash(String modelId, String? vadModel) => fnv1a32(
    '$modelId|${config.sttLanguage}'
    '${vadModel == null ? '' : '|vad'}',
  );

  /// The installed VAD model when silence skipping is on, else null.
  Future<String?> _vadModel() async {
    final skip = await db.settingsRepository.get(
      SettingKeys.processingSkipSilence,
    );
    final on = switch (skip) {
      Ok(:final value) => value is! bool || value,
      Err() => true,
    };
    if (!on) return null;
    final models = await db.modelsRepository
        .watchAll(type: ModelType.vad)
        .first;
    for (final m in models) {
      try {
        final path = paths.resolve(m.path);
        if (File(path).existsSync()) return path;
      } on Object {
        continue; // corrupt row (absolute / escaping path): ignore
      }
    }
    return null;
  }

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final String modelId;
    if (activeModel case final lookup?) {
      final id = await lookup(HeavyModel.stt);
      // No usable STT model installed: wait instead of failing (MDL-02
      // install / MDL-03 selection resumes the job).
      if (id == null) return const StepWaiting(WaitingReason.modelMissing);
      modelId = id;
    } else {
      modelId = config.sttModelId;
    }
    final chunks = await db.recordingsRepository
        .watchChunks(job.recordingId)
        .first;
    if (chunks.isEmpty) {
      return const StepFailed(
        StorageFailure('no audio chunks'),
        kind: FailureKind.permanent,
      );
    }
    final transcriptId = transcriptIdFor(job.id);
    final vadModel = await _vadModel();
    final paramsHash = _paramsHash(modelId, vadModel);
    final cp = job.checkpoint;
    final resumable =
        cp['paramsHash'] == paramsHash && cp['modelId'] == modelId;
    var next = resumable ? (cp['nextChunk'] as int? ?? 0) : 0;

    Map<String, Object?> checkpoint(int nextChunk) => {
      'nextChunk': nextChunk,
      'modelId': modelId,
      'paramsHash': paramsHash,
    };

    if (next == 0) {
      // Fresh start: (re)create the transcript and drop stale segments.
      await ctx.saveCheckpoint(
        checkpoint(0),
        progress: 0,
        writes: () async {
          await db
              .into(db.transcripts)
              .insertOnConflictUpdate(
                TranscriptsCompanion.insert(
                  id: transcriptId,
                  recordingId: job.recordingId,
                  modelId: modelId,
                  language: config.sttLanguage,
                  createdAt: clock.now(),
                ),
              );
          await (db.delete(
            db.transcriptSegments,
          )..where((s) => s.transcriptId.equals(transcriptId))).go();
          await (db.delete(
            db.speechSegments,
          )..where((s) => s.recordingId.equals(job.recordingId))).go();
        },
      );
    }

    final total = chunks.length;
    for (; next < total; next++) {
      if (ctx.cancel.isCancelled) return const StepFailed(CancelledFailure());
      final chunk = chunks[next];
      final done = next;
      final file = paths.resolve(chunk.path);
      final speech = await _speech(vadModel, file, chunk.startMs, job);
      final result = await stt.transcribe(
        file,
        cancel: ctx.cancel,
        onProgress: (f) => ctx.reportProgress((done + f) / total),
        options: SttOptions(
          language: config.sttLanguage,
          vadModelPath: vadModel,
        ),
      );
      switch (result) {
        case Err(:final failure):
          return StepFailed(failure);
        case Ok(value: final transcript):
          final rows = [
            for (final (i, s) in transcript.segments.indexed)
              TranscriptSegmentsCompanion.insert(
                transcriptId: transcriptId,
                seq: segmentSeq(chunk.seq, i),
                startMs: chunk.startMs + s.start.inMilliseconds,
                endMs: chunk.startMs + s.end.inMilliseconds,
                body: s.text,
                // STT-03: confidence + tokens for STT-06 highlighting.
                avgLogprob: Value(s.avgLogprob),
                tokensJson: Value(segmentTokensJson(s)),
              ),
          ];
          await ctx.saveCheckpoint(
            checkpoint(next + 1),
            progress: (next + 1) / total,
            writes: () async {
              unwrap(await db.transcriptsRepository.upsertSegments(rows));
              if (speech.isNotEmpty) {
                await db.batch((b) => b.insertAll(db.speechSegments, speech));
              }
            },
          );
      }
    }
    return const StepSucceeded();
  }

  /// Speech spans of one chunk on the recording timeline. A VAD failure only
  /// loses the timeline, never the transcript.
  Future<List<SpeechSegmentsCompanion>> _speech(
    String? vadModel,
    String file,
    int chunkStartMs,
    JobSnapshot job,
  ) async {
    final engine = vad;
    if (vadModel == null || engine == null) return const [];
    final r = await engine.speechSegments(vadModel, file);
    return switch (r) {
      Ok(:final value) => [
        for (final s in value)
          SpeechSegmentsCompanion.insert(
            recordingId: job.recordingId,
            startMs: chunkStartMs + s.startMs,
            endMs: chunkStartMs + s.endMs,
          ),
      ],
      Err() => const [],
    };
  }
}

/// `transcript_segments.tokens_json`: `[{text,p,t0_ms,t1_ms}]` (STT-06
/// low-confidence highlighting), or null when the engine gave no tokens.
String? segmentTokensJson(TranscriptSegment s) => s.tokens.isEmpty
    ? null
    : jsonEncode([
        for (final t in s.tokens)
          {
            'text': t.text,
            'p': t.p,
            't0_ms': t.start?.inMilliseconds,
            't1_ms': t.end?.inMilliseconds,
          },
      ]);
