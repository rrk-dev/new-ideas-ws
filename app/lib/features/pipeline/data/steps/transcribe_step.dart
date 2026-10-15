import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
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
import 'package:vaultvoice/features/profiles/domain/vocabulary_hints.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
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
/// AUD-03 silence skipping (integration wave 3: one [VadEngine]): when a VAD
/// model is installed and `processing.skip_silence` is on (default), the
/// recording's speech spans come from [vad] (stored as `speech_segments`)
/// and bound STT-04's windows; on the per-chunk path whisper.cpp's built-in
/// Silero VAD also skips silence inside each chunk.
///
/// The model is the active STT model (FND-11 [activeModel]; none installed
/// ⇒ `waiting(model_missing)`). A resume skips finished work only when the
/// parameters hash (model, language, VAD) matches; otherwise it starts over
/// and replaces the old segments.
class TranscribeStep implements PipelineStep {
  TranscribeStep({
    required this.db,
    required this.paths,
    required this.stt,
    required this.config,
    this.clock = const SystemClock(),
    this.activeModel,
    this.vad,
    this.profiles,
    this.windowCache = const NoWindowResultCache(),
    this.windowConfig = const WindowPlanConfig(),
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final SttEngine stt;
  final PipelineConfig config;
  final Clock clock;

  /// The active STT model (FND-11); null uses [PipelineConfig.sttModelId].
  final ActiveModelIdLookup? activeModel;

  /// Computes speech spans when a recording has none stored (AUD-03).
  final VadEngine? vad;

  /// Profile lookup for the STT vocabulary hints (PRF-05); null = none.
  final ProfileLookup? profiles;
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

  String _paramsHash(String modelId, String? vadModel, String? vocabulary) =>
      fnv1a32(
        '$modelId|${config.sttLanguage}'
        '${vadModel == null ? '' : '|vad'}'
        '${vocabulary == null ? '' : '|v:$vocabulary'}',
      );

  /// Vocabulary prompt of the recording's profile (its `stt.vocabulary` plus
  /// the user's additions); null for Auto / unknown profiles or no terms.
  Future<String?> _vocabulary(String recordingId) async {
    final lookup = profiles;
    if (lookup == null) return null;
    final rec = (await db.recordingsRepository.get(recordingId)).valueOrNull;
    final profileId = rec?.profileId;
    if (profileId == null) return null;
    final profile = await lookup(profileId);
    if (profile == null) return null;
    final stored = (await db.settingsRepository.get(
      SettingKeys.vocabularyFor(profileId),
    )).valueOrNull;
    return VocabularyHints.prompt(
      VocabularyHints.merge(profile.stt.vocabulary, [
        if (stored is List) ...stored.whereType<String>(),
      ]),
    );
  }

  /// The installed VAD model when silence skipping is on, else null.
  Future<bool> _skipSilenceOn() async {
    final skip = await db.settingsRepository.get(
      SettingKeys.processingSkipSilence,
    );
    return switch (skip) {
      Ok(:final value) => value is! bool || value,
      Err() => true,
    };
  }

  Future<String?> _vadModel() async {
    if (!await _skipSilenceOn()) return null;
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
    final vadModel = await _vadModel();
    final vocabulary = await _vocabulary(job.recordingId);
    if (stt case final WindowedSttEngine windowed) {
      return await _runWindows(
        ctx,
        chunks,
        windowed,
        modelId,
        vadModel,
        vocabulary,
      );
    }
    final transcriptId = transcriptIdFor(job.id);
    final paramsHash = _paramsHash(modelId, vadModel, vocabulary);
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
      final speech = await _chunkSpeech(vadModel, file, chunk, job, ctx);
      final result = await stt.transcribe(
        file,
        cancel: ctx.cancel,
        onProgress: (f) => ctx.reportProgress((done + f) / total),
        options: SttOptions(
          language: config.sttLanguage,
          initialPrompt: vocabulary,
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

  /// Speech spans of one chunk on the recording timeline (per-chunk path).
  /// A VAD failure only loses the timeline, never the transcript.
  Future<List<SpeechSegmentsCompanion>> _chunkSpeech(
    String? vadModel,
    String file,
    AudioChunkRow chunk,
    JobSnapshot job,
    StepContext ctx,
  ) async {
    final engine = vad;
    if (vadModel == null || engine == null) return const [];
    final r = await engine.detect(
      [(path: file, startMs: chunk.startMs, endMs: chunk.endMs)],
      modelPath: vadModel,
      cancel: ctx.cancel,
    );
    return switch (r) {
      Ok(:final value) => [
        for (final s in value)
          SpeechSegmentsCompanion.insert(
            recordingId: job.recordingId,
            startMs: s.startMs,
            endMs: s.endMs,
          ),
      ],
      Err() => const [],
    };
  }

  Future<StepResult> _runWindows(
    StepContext ctx,
    List<AudioChunkRow> chunks,
    WindowedSttEngine engine,
    String modelId,
    String? vadModel,
    String? vocabulary,
  ) async {
    final job = ctx.job;
    final speech = await _speechSpans(job.recordingId, chunks, ctx, vadModel);
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
      speech: speech.valueOrNull!.spans,
      vadRan: speech.valueOrNull!.known,
      config: windowConfig,
    );
    final windows = plan.windows;
    final transcriptId = transcriptIdFor(job.id);
    // The vocabulary is only a hint: it stays out of the key so windows
    // transcribed while recording (no profile terms yet) remain reusable.
    final paramsKey = sttParamsKey(modelId, config.sttLanguage);
    final paramsHash = fnv1a32(
      '$paramsKey|${vadModel == null ? '' : 'vad|'}'
      '${windows.map((w) => w.key).join(',')}',
    );
    final cp = job.checkpoint;
    final resumable =
        cp['paramsHash'] == paramsHash &&
        cp['modelId'] == modelId &&
        cp.containsKey('nextWindow');
    var next = resumable ? (cp['nextWindow'] as int? ?? 0) : 0;

    Map<String, Object?> checkpoint(int nextWindow) => {
      'nextWindow': nextWindow,
      'modelId': modelId,
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
                  modelId: modelId,
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
            initialPrompt: carryPrompt(
              vocabulary: vocabulary,
              previousText: previous,
            ),
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
  /// boundaries are then the cut points: no VAD model, or silence skipping
  /// off).
  Future<Result<({List<SpeechSpan> spans, bool known})>> _speechSpans(
    String recordingId,
    List<AudioChunkRow> chunks,
    StepContext ctx,
    String? vadModel,
  ) async {
    // Silence skipping off: stored spans from an earlier run must not apply.
    if (!await _skipSilenceOn()) {
      return const Ok((spans: <SpeechSpan>[], known: false));
    }
    final stored = await db.recordingsRepository
        .watchSpeechSegments(recordingId)
        .first;
    if (stored.isNotEmpty) {
      return Ok((
        spans: [for (final s in stored) SpeechSpan(s.startMs, s.endMs)],
        known: true,
      ));
    }
    final engine = vad;
    if (engine == null || vadModel == null) {
      return const Ok((spans: <SpeechSpan>[], known: false));
    }
    final detected = await engine.detect(
      [
        for (final c in chunks)
          (path: paths.resolve(c.path), startMs: c.startMs, endMs: c.endMs),
      ],
      modelPath: vadModel,
      cancel: ctx.cancel,
    );
    switch (detected) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.isNotEmpty) {
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
        return Ok((spans: value, known: true));
    }
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
