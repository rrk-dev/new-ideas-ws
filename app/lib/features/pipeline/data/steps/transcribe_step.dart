import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// Transcribes the recording's audio chunks one by one, checkpointing after
/// every chunk (`{nextChunk, modelId, paramsHash}`). A resume skips finished
/// chunks only when the parameters hash matches; otherwise it starts over and
/// replaces the old segments.
class TranscribeStep implements PipelineStep {
  TranscribeStep({
    required this.db,
    required this.paths,
    required this.stt,
    required this.config,
    this.clock = const SystemClock(),
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final SttEngine stt;
  final PipelineConfig config;
  final Clock clock;

  @override
  PipelineStepId get id => PipelineStepId.transcribe;

  @override
  HeavyModel get model => HeavyModel.stt;

  @override
  bool canRun(JobSnapshot job) => true;

  String get _paramsHash =>
      fnv1a32('${config.sttModelId}|${config.sttLanguage}');

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
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
    final cp = job.checkpoint;
    final resumable =
        cp['paramsHash'] == _paramsHash && cp['modelId'] == config.sttModelId;
    var next = resumable ? (cp['nextChunk'] as int? ?? 0) : 0;

    Map<String, Object?> checkpoint(int nextChunk) => {
      'nextChunk': nextChunk,
      'modelId': config.sttModelId,
      'paramsHash': _paramsHash,
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
                  modelId: config.sttModelId,
                  language: config.sttLanguage,
                  createdAt: clock.now(),
                ),
              );
          await (db.delete(
            db.transcriptSegments,
          )..where((s) => s.transcriptId.equals(transcriptId))).go();
        },
      );
    }

    final total = chunks.length;
    for (; next < total; next++) {
      if (ctx.cancel.isCancelled) return const StepFailed(CancelledFailure());
      final chunk = chunks[next];
      final done = next;
      final result = await stt.transcribe(
        paths.resolve(chunk.path),
        cancel: ctx.cancel,
        onProgress: (f) => ctx.reportProgress((done + f) / total),
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
              ),
          ];
          await ctx.saveCheckpoint(
            checkpoint(next + 1),
            progress: (next + 1) / total,
            writes: () async =>
                unwrap(await db.transcriptsRepository.upsertSegments(rows)),
          );
      }
    }
    return const StepSucceeded();
  }
}
