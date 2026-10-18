import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/extract_step.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_inputs.dart';

/// Resolves the map-reduce input of one extraction: prompts, schemas and
/// grammars of [profile], the device tier and the checkpoint params key.
/// Null means "not applicable" (e.g. no map grammar): `ExtractStep` then
/// runs its single-pass structured extraction.
typedef LongExtractionInputFor = Future<LongExtractionInput?> Function(
  Profile profile,
  List<TranscriptLine> lines, {
  required String modelId,
  required int maxTokens,
  PromptMetadata? metadata,
});

/// LLM-06 extraction through [MapReduceExtractor] (token-budget plan, chunked
/// map step with per-chunk checkpoints, deterministic reduce).
final class LongTranscriptExtraction {
  const LongTranscriptExtraction({
    required this.extractor,
    required this.inputFor,
  });

  final MapReduceExtractor extractor;
  final LongExtractionInputFor inputFor;
}

/// [ExtractionStrategy] adapter over [LongTranscriptExtraction] (integration
/// wave 3: FND-11 seam ↔ LLM-06). The extractor plans single-pass vs
/// map-reduce itself from exact token counts, so short transcripts take the
/// same single structured pass (same prompts, same validation) as
/// `ExtractStep`; a failed structured pass is stored as `{title, summary}`.
final class LongTranscriptStrategy implements ExtractionStrategy {
  const LongTranscriptStrategy(this.long);

  final LongTranscriptExtraction long;

  @override
  Future<Result<ExtractedData>?> extract(
    StepContext ctx, {
    required Profile profile,
    required String grammar,
    required List<TranscriptSegmentRow> segments,
    required int maxTokens,
    required String modelId,
    PromptMetadata? metadata,
  }) async {
    final lines = [
      for (final s in segments)
        TranscriptLine(startMs: s.startMs, speaker: s.speaker, text: s.body),
    ];
    final input = await long.inputFor(
      profile,
      lines,
      modelId: modelId,
      maxTokens: maxTokens,
      metadata: metadata,
    );
    if (input == null) return null;
    final result = await long.extractor.extract(
      input,
      cancel: ctx.cancel,
      onProgress: ctx.reportProgress,
      checkpoints: StepCheckpointStore(ctx),
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(value: final r) => Ok(
        ExtractedData(
          valid: r.outcome.valid,
          json: r.outcome.valid
              ? r.outcome.data!
              : ExtractStep.fallbackExtractionJson(r.outcome.fallbackSummary),
        ),
      ),
    };
  }
}

/// Map checkpoints through the orchestrator (one transaction per chunk).
final class StepCheckpointStore implements MapReduceCheckpointStore {
  StepCheckpointStore(this._ctx)
    : initial = MapReduceCheckpoint.fromJson(_ctx.job.checkpoint);

  final StepContext _ctx;

  @override
  final MapReduceCheckpoint? initial;

  @override
  Future<void> save(MapReduceCheckpoint checkpoint, double progress) =>
      _ctx.saveCheckpoint(checkpoint.toJson(), progress: progress);
}
