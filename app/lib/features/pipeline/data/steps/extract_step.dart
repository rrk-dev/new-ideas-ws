import 'dart:convert';

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// Builds the extraction prompt. PRF-02 replaces the placeholder with the
/// profile prompt builder (and LLM-05/06 add grammars and map-reduce).
typedef ExtractionPromptBuilder = LlmRequest Function(
  String profileId,
  String transcript,
  int maxTokens,
);

LlmRequest _placeholderPrompt(String profileId, String text, int maxTokens) =>
    LlmRequest(
      prompt:
          'Extract the "$profileId" fields from this transcript as one JSON '
          'object.\n\n$text',
      maxTokens: maxTokens,
    );

/// LLM-06 wiring: extraction through [MapReduceExtractor] (token-budget
/// plan, chunked map step with per-chunk checkpoints, deterministic reduce).
/// [inputFor] resolves the profile's prompts/schemas/grammars and the device
/// tier; null means "use the plain single prompt" (e.g. no grammar yet).
final class LongTranscriptExtraction {
  const LongTranscriptExtraction({
    required this.extractor,
    required this.inputFor,
  });

  final MapReduceExtractor extractor;
  final Future<LongExtractionInput?> Function(
    String profileId,
    List<TranscriptLine> lines,
  )
  inputFor;
}

/// Runs the LLM over the latest transcript and stores the extraction under a
/// job-keyed id (re-extract overwrites). Never invokes STT.
class ExtractStep implements PipelineStep {
  ExtractStep({
    required this.db,
    required this.llm,
    required this.config,
    this.clock = const SystemClock(),
    ExtractionPromptBuilder? promptBuilder,
    this.longTranscript,
  }) : promptBuilder = promptBuilder ?? _placeholderPrompt;

  final VaultVoiceDatabase db;
  final LlmEngine llm;
  final PipelineConfig config;
  final Clock clock;
  final ExtractionPromptBuilder promptBuilder;
  final LongTranscriptExtraction? longTranscript;

  @override
  PipelineStepId get id => PipelineStepId.extract;

  @override
  HeavyModel get model => HeavyModel.llm;

  @override
  bool canRun(JobSnapshot job) => true;

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final transcript = unwrap(
      await db.transcriptsRepository.latestFor(job.recordingId),
    );
    if (transcript == null) {
      return const StepFailed(
        StorageFailure('no transcript'),
        kind: FailureKind.permanent,
      );
    }
    final segments = unwrap(
      await db.transcriptsRepository.segments(transcript.id),
    );
    final recording = unwrap(
      await db.recordingsRepository.get(job.recordingId),
    );
    final profileId = recording.profileId ?? config.defaultProfileId;
    final profile = await db.profilesRepository.getProfile(profileId);
    final profileVersion = profile.valueOrNull?.version ?? 1;

    if (longTranscript case final lt?) {
      final lines = [
        for (final s in segments)
          TranscriptLine(startMs: s.startMs, speaker: s.speaker, text: s.body),
      ];
      final input = await lt.inputFor(profileId, lines);
      if (input != null) {
        final result = await lt.extractor.extract(
          input,
          cancel: ctx.cancel,
          onProgress: ctx.reportProgress,
          checkpoints: _StepCheckpoints(ctx),
        );
        switch (result) {
          case Err(:final failure):
            return StepFailed(failure);
          case Ok(value: final r):
            final o = r.outcome;
            return StepSucceeded(
              commit: () async {
                unwrap(
                  await db.extractionsRepository.upsert(
                    ExtractionsCompanion.insert(
                      id: extractionIdFor(job.id),
                      recordingId: job.recordingId,
                      profileId: profileId,
                      profileVersion: profileVersion,
                      modelId: config.llmModelId,
                      json:
                          o.data ??
                          {'fallback_summary': o.fallbackSummary ?? ''},
                      valid: o.valid,
                      createdAt: clock.now(),
                    ),
                  ),
                );
              },
            );
        }
      }
    }

    final request = promptBuilder(
      profileId,
      segments.map((s) => s.body).join('\n'),
      config.maxLlmTokens,
    );
    var tokens = 0;
    final result = await llm.generate(
      request,
      cancel: ctx.cancel,
      onToken: (_) => ctx.reportProgress(++tokens / request.maxTokens),
    );
    switch (result) {
      case Err(:final failure):
        return StepFailed(failure);
      case Ok(value: final output):
        final parsed = _parseObject(output);
        return StepSucceeded(
          commit: () async {
            unwrap(
              await db.extractionsRepository.upsert(
                ExtractionsCompanion.insert(
                  id: extractionIdFor(job.id),
                  recordingId: job.recordingId,
                  profileId: profileId,
                  profileVersion: profileVersion,
                  modelId: config.llmModelId,
                  json: parsed ?? {'raw': output},
                  valid: parsed != null,
                  createdAt: clock.now(),
                ),
              ),
            );
          },
        );
    }
  }

  static Map<String, Object?>? _parseObject(String output) {
    try {
      final decoded = jsonDecode(output);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

/// Map checkpoints through the orchestrator (one transaction per chunk).
final class _StepCheckpoints implements MapReduceCheckpointStore {
  _StepCheckpoints(this._ctx)
    : initial = MapReduceCheckpoint.fromJson(_ctx.job.checkpoint);

  final StepContext _ctx;

  @override
  final MapReduceCheckpoint? initial;

  @override
  Future<void> save(MapReduceCheckpoint checkpoint, double progress) =>
      _ctx.saveCheckpoint(checkpoint.toJson(), progress: progress);
}
