import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
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
import 'package:vaultvoice/features/transcription/data/window_result_cache.dart';
import 'package:vaultvoice/features/transcription/domain/hallucination_guards.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';

/// Transcribes a recording.
///
/// - **Long-form (STT-04)**, when the engine is a [WindowedSttEngine]: the
///   audio is planned into 30-120 s VAD-bounded speech windows
///   ([planWindows]; speech spans from `speech_segments`, computed once by
///   [vad] when missing), each decoded with one `vv_stt_transcribe_ranges`
///   call (no temp WAVs), segments mapped to the recording timeline, run
///   through the hallucination/repetition guards and committed together with
///   the checkpoint `{nextWindow, modelId, paramsHash}` - a killed job
///   resumes at the next window. The previous window's tail is carried into
///   the prompt. Windows already transcribed while recording
///   (near-real-time mode) are taken from [windowCache].
/// - **Per chunk** (engines without range support, e.g. test fakes): one
///   call per chunk with checkpoint `{nextChunk, ...}` (FND-05 behaviour).
///
/// A resume skips finished work only when the parameters hash matches;
/// otherwise it starts over and replaces the old segments.
class TranscribeStep implements PipelineStep {
  TranscribeStep({
    required this.db,
    required this.paths,
    required this.stt,
    required this.config,
    this.clock = const SystemClock(),
    this.vad,
    this.windowCache = const NoWindowResultCache(),
    this.windowConfig = const WindowPlanConfig(),
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final SttEngine stt;
  final PipelineConfig config;
  final Clock clock;

  /// Computes speech spans when a recording has none stored (AUD-03).
  final VadEngine? vad;
  final WindowResultCache windowCache;
  final WindowPlanConfig windowConfig;

  /// Dropped segments per guard reason in the last run (diagnostics only).
  final Map<GuardReason, int> guardDrops = {};

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
    if (stt case final WindowedSttEngine windowed) {
      return await _runWindows(ctx, chunks, windowed);
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
        options: SttOptions(language: config.sttLanguage),
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
            },
          );
      }
    }
    return const StepSucceeded();
  }

  Future<StepResult> _runWindows(
    StepContext ctx,
    List<AudioChunkRow> chunks,
    WindowedSttEngine engine,
  ) async {
    final job = ctx.job;
    final speech = await _speechSpans(job.recordingId, chunks, ctx);
    if (speech case Err(:final failure)) return StepFailed(failure);
    final plan = planWindows(
      chunks: [
        for (final c in chunks)
          PlanChunk(
            seq: c.seq,
            path: paths.resolve(c.path),
            startMs: c.startMs,
            endMs: c.endMs,
          ),
      ],
      speech: speech.valueOrNull!,
      config: windowConfig,
    );
    final windows = plan.windows;
    final transcriptId = transcriptIdFor(job.id);
    final paramsKey = sttParamsKey(config.sttModelId, config.sttLanguage);
    final paramsHash = fnv1a32(
      '$paramsKey|${windows.map((w) => w.key).join(',')}',
    );
    final cp = job.checkpoint;
    final resumable =
        cp['paramsHash'] == paramsHash &&
        cp['modelId'] == config.sttModelId &&
        cp.containsKey('nextWindow');
    var next = resumable ? (cp['nextWindow'] as int? ?? 0) : 0;

    Map<String, Object?> checkpoint(int nextWindow) => {
      'nextWindow': nextWindow,
      'modelId': config.sttModelId,
      'paramsHash': paramsHash,
    };

    if (next == 0) {
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
    if (windows.isEmpty) return const StepSucceeded(); // silence only

    final totalMs = windows.fold<int>(0, (a, w) => a + w.audioMs);
    var doneMs = windows.take(next).fold<int>(0, (a, w) => a + w.audioMs);
    // Prompt continuity across a resume: the last kept text before [next].
    var previous = next == 0 ? null : await _lastText(transcriptId, next);
    guardDrops.clear();

    for (; next < windows.length; next++) {
      if (ctx.cancel.isCancelled) return const StepFailed(CancelledFailure());
      final w = windows[next];
      final before = doneMs;
      var segments = await windowCache.lookup(
        job.recordingId,
        w.key,
        paramsKey,
      );
      if (segments == null) {
        final result = await engine.transcribeRanges(
          [
            for (final r in w.ranges)
              SttAudioRange(
                path: r.path,
                startMs: r.fileStartMs,
                endMs: r.fileEndMs,
                recordingOffsetMs: r.recordingOffsetMs,
              ),
          ],
          cancel: ctx.cancel,
          onProgress: (f) =>
              ctx.reportProgress((before + f * w.audioMs) / totalMs),
          options: SttOptions(
            language: config.sttLanguage,
            initialPrompt: carryPrompt(previousText: previous),
          ),
        );
        switch (result) {
          case Err(:final failure):
            return StepFailed(failure);
          case Ok(value: final transcript):
            segments = transcript.segments;
        }
      }
      final guarded = applyGuards(segments, previous: previous);
      guarded.dropped.forEach(
        (k, v) => guardDrops[k] = (guardDrops[k] ?? 0) + v,
      );
      final rows = [
        for (final (i, s) in guarded.kept.indexed)
          TranscriptSegmentsCompanion.insert(
            transcriptId: transcriptId,
            seq: segmentSeq(w.index, i),
            startMs: s.start.inMilliseconds,
            endMs: s.end.inMilliseconds,
            body: s.text,
            avgLogprob: Value(s.avgLogprob),
            tokensJson: Value(segmentTokensJson(s)),
          ),
      ];
      doneMs += w.audioMs;
      final windowIndex = w.index;
      await ctx.saveCheckpoint(
        checkpoint(next + 1),
        progress: doneMs / totalMs,
        writes: () async {
          // Idempotent per window: replace whatever this window wrote.
          await (db.delete(db.transcriptSegments)..where(
                (s) =>
                    s.transcriptId.equals(transcriptId) &
                    s.seq.isBetweenValues(
                      segmentSeq(windowIndex, 0),
                      segmentSeq(windowIndex + 1, 0) - 1,
                    ),
              ))
              .go();
          unwrap(await db.transcriptsRepository.upsertSegments(rows));
        },
      );
      if (guarded.kept.isNotEmpty) {
        previous = guarded.kept.map((s) => s.text).join(' ');
      }
    }
    await windowCache.clear(job.recordingId);
    return const StepSucceeded();
  }

  /// Stored speech spans, or VAD's (stored for next time), or none (chunk
  /// boundaries are then the cut points).
  Future<Result<List<SpeechSpan>>> _speechSpans(
    String recordingId,
    List<AudioChunkRow> chunks,
    StepContext ctx,
  ) async {
    final stored = await db.recordingsRepository
        .watchSpeechSegments(recordingId)
        .first;
    if (stored.isNotEmpty) {
      return Ok([for (final s in stored) SpeechSpan(s.startMs, s.endMs)]);
    }
    final engine = vad;
    if (engine == null) return const Ok([]);
    final detected = await engine.detect([
      for (final c in chunks)
        (path: paths.resolve(c.path), startMs: c.startMs, endMs: c.endMs),
    ], cancel: ctx.cancel);
    if (detected case Ok(:final value) when value.isNotEmpty) {
      final saved = await db.recordingsRepository.replaceSpeechSegments(
        recordingId,
        [
          for (final s in value)
            SpeechSegmentsCompanion.insert(
              recordingId: recordingId,
              startMs: s.startMs,
              endMs: s.endMs,
            ),
        ],
      );
      if (saved case Err(:final failure)) return Err(failure);
    }
    return detected;
  }

  Future<String?> _lastText(String transcriptId, int window) async {
    final rows =
        await (db.select(db.transcriptSegments)
              ..where(
                (s) =>
                    s.transcriptId.equals(transcriptId) &
                    s.seq.isSmallerThanValue(segmentSeq(window, 0)),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.seq)])
              ..limit(3))
            .get();
    if (rows.isEmpty) return null;
    return rows.reversed.map((r) => r.body).join(' ');
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
