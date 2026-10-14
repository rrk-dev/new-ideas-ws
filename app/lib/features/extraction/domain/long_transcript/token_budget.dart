import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// How one extraction runs (LLM-06, vv-llm-inference → Token budget).
enum ExtractionMode {
  /// Whole transcript in one prompt, with the profile's few-shot examples.
  singlePass,

  /// One prompt, examples dropped to make it fit (prompt-builder rule:
  /// over budget → drop examples → then map-reduce).
  singlePassNoExamples,

  /// Chunked map step + deterministic/LLM reduce.
  mapReduce,
}

/// Largest map chunk (transcript tokens) per device tier, even when the
/// context would allow more. Smaller chunks bound prefill time and compute
/// buffers on slow devices and keep small models from losing items in the
/// middle of long prompts. Engineering default; tune with the PRF-09 /
/// LLM-08 eval (recall vs chunk size) — see docs/long-transcripts.md.
int maxChunkTokensFor(DeviceTier tier) => switch (tier) {
  DeviceTier.low => 2048,
  DeviceTier.mid => 3072,
  DeviceTier.high => 4096,
};

/// Result of [TokenBudgetPlanner.plan] (content-free; safe to log).
@immutable
final class ExtractionPlan {
  const ExtractionPlan({
    required this.mode,
    required this.contextWindow,
    required this.transcriptTokens,
    required this.maxOutputTokens,
    this.chunkTokens = 0,
    this.overlapTokens = 0,
    this.estimatedChunks = 1,
  });

  final ExtractionMode mode;

  /// n_ctx of the loaded model (after the LLM-07 memory gate).
  final int contextWindow;
  final int transcriptTokens;

  /// Output reserve per call (`n_predict`); smaller for map calls.
  final int maxOutputTokens;

  /// Map step: transcript tokens per chunk (target, incl. overlap).
  final int chunkTokens;

  /// Map step: tokens repeated from the end of the previous chunk (~10%).
  final int overlapTokens;
  final int estimatedChunks;

  bool get isMapReduce => mode == ExtractionMode.mapReduce;

  @override
  String toString() =>
      'ExtractionPlan(${mode.name}, ctx $contextWindow, transcript '
      '$transcriptTokens, chunk $chunkTokens/$overlapTokens, '
      '~$estimatedChunks chunks)';
}

/// The context is too small for even one map chunk.
final class ContextTooSmall implements Exception {
  const ContextTooSmall(this.contextWindow, this.chunkBudget);

  final int contextWindow;
  final int chunkBudget;

  @override
  String toString() => 'ContextTooSmall(ctx $contextWindow, $chunkBudget)';
}

/// Chooses single-pass vs map-reduce from exact token counts
/// (`budget = n_ctx − n_predict_reserve − prompt_overhead − safety`).
///
/// Device RAM enters twice: the LLM-07 load gate already lowered n_ctx to
/// what fits in memory (`contextWindow` is the *effective* context), and
/// the tier caps the map chunk size ([maxChunkTokensFor]).
final class TokenBudgetPlanner {
  const TokenBudgetPlanner({
    this.safetyTokens = 64,
    this.overlapFraction = 0.10,
    this.minChunkTokens = 384,
    this.minMapOutputTokens = 256,
  });

  /// Slack for tokenizer merges across line joins and template variance.
  final int safetyTokens;
  final double overlapFraction;

  /// A map chunk smaller than this is not worth running.
  final int minChunkTokens;
  final int minMapOutputTokens;

  /// Output reserve for one map call: the profile's limit, but at most a
  /// quarter of the context (partial results are small; transcript space
  /// matters more).
  int mapOutputTokens(int contextWindow, int maxOutputTokens) {
    final quarter = contextWindow ~/ 4;
    final cap = quarter < minMapOutputTokens ? minMapOutputTokens : quarter;
    return maxOutputTokens < cap ? maxOutputTokens : cap;
  }

  /// [singlePromptTokens] / [singlePromptTokensNoExamples]: exact tokens of
  /// the complete templated single-pass prompt with / without examples.
  /// [mapOverheadTokens]: templated map prompt with an empty transcript.
  ///
  /// Throws [ContextTooSmall] when no plan fits.
  ExtractionPlan plan({
    required int contextWindow,
    required int transcriptTokens,
    required int maxOutputTokens,
    required int singlePromptTokens,
    required int singlePromptTokensNoExamples,
    required int mapOverheadTokens,
    required DeviceTier tier,
  }) {
    final singleLimit = contextWindow - maxOutputTokens - safetyTokens;
    if (singlePromptTokens <= singleLimit) {
      return ExtractionPlan(
        mode: ExtractionMode.singlePass,
        contextWindow: contextWindow,
        transcriptTokens: transcriptTokens,
        maxOutputTokens: maxOutputTokens,
      );
    }
    if (singlePromptTokensNoExamples <= singleLimit) {
      return ExtractionPlan(
        mode: ExtractionMode.singlePassNoExamples,
        contextWindow: contextWindow,
        transcriptTokens: transcriptTokens,
        maxOutputTokens: maxOutputTokens,
      );
    }
    final mapOut = mapOutputTokens(contextWindow, maxOutputTokens);
    final budget = contextWindow - mapOut - mapOverheadTokens - safetyTokens;
    final cap = maxChunkTokensFor(tier);
    final chunk = budget < cap ? budget : cap;
    if (chunk < minChunkTokens) throw ContextTooSmall(contextWindow, budget);
    final overlap = (chunk * overlapFraction).floor();
    return ExtractionPlan(
      mode: ExtractionMode.mapReduce,
      contextWindow: contextWindow,
      transcriptTokens: transcriptTokens,
      maxOutputTokens: mapOut,
      chunkTokens: chunk,
      overlapTokens: overlap,
      estimatedChunks: estimateChunks(transcriptTokens, chunk, overlap),
    );
  }

  /// Chunks needed for [tokens] with [chunk]-sized windows that advance by
  /// `chunk − overlap`.
  static int estimateChunks(int tokens, int chunk, int overlap) {
    if (tokens <= chunk) return 1;
    final step = chunk - overlap;
    return 1 + ((tokens - chunk) + step - 1) ~/ step;
  }
}
