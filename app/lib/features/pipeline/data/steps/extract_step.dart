import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/structured_extractor.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/domain/extraction_prompts.dart';
import 'package:vaultvoice/features/profiles/domain/post_processing.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_inputs.dart';

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
///
/// With a [profiles] + [grammars] resolver (production, FND-11) the profile's
/// schema grammar constrains decoding and [StructuredExtractor] validates,
/// repairs once and falls back to a free-text summary (`valid = false`);
/// otherwise the FND-05 placeholder prompt runs unconstrained.
class ExtractStep implements PipelineStep {
  ExtractStep({
    required this.db,
    required this.llm,
    required this.config,
    this.clock = const SystemClock(),
    ExtractionPromptBuilder? promptBuilder,
    this.activeModel,
    this.profiles,
    this.grammars,
    this.strategy,
    this.prompts = ExtractionPrompts.new,
  }) : promptBuilder = promptBuilder ?? _placeholderPrompt;

  final VaultVoiceDatabase db;
  final LlmEngine llm;
  final PipelineConfig config;
  final Clock clock;
  final ExtractionPromptBuilder promptBuilder;
  final ActiveModelIdLookup? activeModel;
  final ProfileLookup? profiles;
  final ProfileGrammarLookup? grammars;

  /// Long-transcript extraction (LLM-06 seam), tried first on the profile
  /// path.
  final ExtractionStrategy? strategy;

  /// PRF-02 prompts of the profile path (`extractionPromptsProvider`'s
  /// factory; the worker has no Riverpod scope, so it is passed in).
  final ExtractionPromptsFactory prompts;

  @override
  PipelineStepId get id => PipelineStepId.extract;

  @override
  HeavyModel get model => HeavyModel.llm;

  @override
  bool canRun(JobSnapshot job) => true;

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final String modelId;
    if (activeModel case final lookup?) {
      final id = await lookup(HeavyModel.llm);
      if (id == null) return const StepWaiting(WaitingReason.modelMissing);
      modelId = id;
    } else {
      modelId = config.llmModelId;
    }
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

    final profile = await profiles?.call(profileId);
    final grammar = profile == null ? null : await grammars?.call(profile);
    final Map<String, Object?> json;
    final bool valid;
    final int profileVersion;
    if (profile != null && grammar != null) {
      profileVersion = profile.version;
      final metadata = await _metadata(recording);
      final long = await strategy?.extract(
        ctx,
        profile: profile,
        grammar: grammar,
        segments: segments,
        maxTokens: config.maxLlmTokens,
        modelId: modelId,
        metadata: metadata,
      );
      final p = prompts(profile, metadata: metadata);
      // PRF-03/04/05: the profile's deterministic Dart post-processors run
      // on every valid result (dates, expiry, serials, owners, timestamps).
      Map<String, Object?> postProcess(Map<String, Object?> data) =>
          applyPostProcessors(
            profile,
            data,
            PostProcessContext.fromTranscriptLines(
              p.transcriptLines(promptSegments(segments)),
              recordedAt: metadata.recordedAt,
              speakers: metadata.speakers,
            ),
          );
      if (long != null) {
        switch (long) {
          case Err(:final failure):
            return StepFailed(failure);
          case Ok(value: final d):
            valid = d.valid;
            json = d.valid ? postProcess(d.json) : d.json;
        }
      } else {
        final outcome = await _structured(ctx, p, profile, grammar, segments);
        switch (outcome) {
          case Err(:final failure):
            return StepFailed(failure);
          case Ok(value: final o):
            valid = o.valid;
            json = o.valid
                ? postProcess(o.data!)
                : fallbackExtractionJson(o.fallbackSummary);
        }
      }
    } else {
      final stored = await db.profilesRepository.getProfile(profileId);
      profileVersion = profile?.version ?? stored.valueOrNull?.version ?? 1;
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
          valid = parsed != null;
          json = parsed ?? {'raw': output};
      }
    }
    return StepSucceeded(
      commit: () async {
        unwrap(
          await db.extractionsRepository.upsert(
            ExtractionsCompanion.insert(
              id: extractionIdFor(job.id),
              recordingId: job.recordingId,
              profileId: profileId,
              profileVersion: profileVersion,
              modelId: modelId,
              json: json,
              valid: valid,
              createdAt: clock.now(),
            ),
          ),
        );
      },
    );
  }

  Future<Result<ExtractionOutcome>> _structured(
    StepContext ctx,
    ExtractionPrompts p,
    Profile profile,
    String grammar,
    List<TranscriptSegmentRow> segments,
  ) {
    // PRF-02 prompts (integration W3): fixed system prompt + instructions +
    // field list; metadata, sanitized `<transcript>` lines, schema reminder.
    final text = p.transcriptLines(promptSegments(segments));
    final maxTokens = config.maxLlmTokens;
    var tokens = 0;
    // Up to three generations (first pass, repair, summary fallback).
    final engine = _ProgressLlm(
      llm,
      (_) => ctx.reportProgress((++tokens / (3 * maxTokens)).clamp(0, 1)),
    );
    return StructuredExtractor(engine).extract(
      ExtractionRequest(
        systemPrompt: p.systemPrompt,
        userPrompt: p.singleUser(text),
        schema: profile.schema.toJson(),
        grammar: grammar,
        transcriptTimestamps: transcriptTimestamps(text),
        maxTokens: maxTokens,
      ),
      cancel: ctx.cancel,
    );
  }

  /// Recording metadata shown to the model: date, duration, speaker names
  /// and user markers (no transcript text).
  Future<PromptMetadata> _metadata(RecordingRow recording) async {
    final speakers = await (db.select(
      db.speakers,
    )..where((t) => t.recordingId.equals(recording.id))).get();
    final markers =
        await (db.select(db.markers)
              ..where(
                (t) =>
                    t.recordingId.equals(recording.id) &
                    t.kind.equalsValue(MarkerKind.user),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.atMs)]))
            .get();
    return PromptMetadata(
      recordedAt: recording.createdAt.toLocal(),
      duration: Duration(milliseconds: recording.durationMs),
      speakers: [
        for (final s in speakers)
          PromptSpeaker(label: s.label, name: s.displayName),
      ],
      markers: [
        for (final m in markers)
          PromptMarker(
            at: Duration(milliseconds: m.atMs),
            label: m.label,
          ),
      ],
    );
  }

  /// Extraction JSON after a failed structured pass: the summary fallback's
  /// first line is the title (`summary-only` template, LLM-05).
  static Map<String, Object?> fallbackExtractionJson(String? summary) {
    final text = (summary ?? '').trim();
    final nl = text.indexOf('\n');
    final title = (nl < 0 ? '' : text.substring(0, nl)).trim();
    final body = (nl < 0 ? text : text.substring(nl + 1)).trim();
    return {
      'title': title.isEmpty ? null : title,
      'summary': body.isEmpty ? null : body,
    };
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

/// Forwards to [_inner], reporting every streamed token.
class _ProgressLlm implements LlmEngine {
  _ProgressLlm(this._inner, this._onToken);

  final LlmEngine _inner;
  final void Function(String token) _onToken;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) => _inner.generate(
    request,
    cancel: cancel,
    onToken: (t) {
      _onToken(t);
      onToken?.call(t);
    },
  );
}

/// Transcript rows as PRF-02 prompt segments.
List<PromptSegment> promptSegments(List<TranscriptSegmentRow> segments) => [
  for (final s in segments)
    PromptSegment(
      start: Duration(milliseconds: s.startMs),
      speaker: s.speaker,
      text: s.body,
    ),
];
