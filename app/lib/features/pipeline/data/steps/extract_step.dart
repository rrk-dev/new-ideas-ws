import 'dart:convert';

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
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

/// Runs the LLM over the latest transcript and stores the extraction under a
/// job-keyed id (re-extract overwrites). Never invokes STT.
class ExtractStep implements PipelineStep {
  ExtractStep({
    required this.db,
    required this.llm,
    required this.config,
    this.clock = const SystemClock(),
    ExtractionPromptBuilder? promptBuilder,
  }) : promptBuilder = promptBuilder ?? _placeholderPrompt;

  final VaultVoiceDatabase db;
  final LlmEngine llm;
  final PipelineConfig config;
  final Clock clock;
  final ExtractionPromptBuilder promptBuilder;

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
          commit: () async => unwrap(
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
          ),
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
