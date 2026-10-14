import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// Sampling presets (vv-llm-inference → "Sampling presets").
enum LlmPreset {
  /// Grammar + temp 0.2, min_p 0.05, top_k 40, no repeat penalty, seed 42.
  extraction,

  /// Greedy (temperature 0), seed 42 — tests and repair attempts.
  deterministic,

  /// Free-text summary: temp 0.5, top_p 0.95, repeat penalty 1.05.
  summary,

  /// Classification (PRF-06): grammar enum, greedy, max 16 tokens.
  classification,
}

/// Sampling settings for one request; [seed]/[temperature] override the
/// preset when set.
class LlmSampling {
  const LlmSampling({
    this.preset = LlmPreset.extraction,
    this.seed,
    this.temperature,
  });

  final LlmPreset preset;
  final int? seed;
  final double? temperature;
}

/// A single prompt execution.
class LlmRequest {
  const LlmRequest({
    required this.prompt,
    this.grammar,
    this.maxTokens = 1024,
    this.systemPrompt,
    this.sampling = const LlmSampling(),
    this.templated = false,
  });

  /// User message (or the full prompt when [templated] is true).
  final String prompt;

  /// Optional GBNF grammar constraining the output.
  final String? grammar;
  final int maxTokens;

  /// System message; the engine applies the model's chat template.
  final String? systemPrompt;
  final LlmSampling sampling;

  /// True when [prompt] already contains the chat template (no wrapping).
  final bool templated;
}

/// Local LLM inference (llama.cpp behind the native bridge).
abstract interface class LlmEngine {
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  });
}
