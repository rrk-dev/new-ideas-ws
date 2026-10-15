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
    this.reusePrefix = false,
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

  /// Keep the KV cache of the prefix this prompt shares with the previous
  /// request (LLM-06 map chunks share the system prompt); engines without a
  /// cache ignore it. Outputs may differ from a full prefill in the last
  /// float bits on GPU backends.
  final bool reusePrefix;
}

/// Exact token counts for budget planning (LLM-06). Counting needs the
/// model's vocabulary, so implementations may load the model first.
abstract interface class LlmTokenizer {
  /// Tokens of [text] (with BOS, as generation adds it).
  Future<Result<int>> countTokens(String text);

  /// Tokens of the chat-templated prompt (system + user + assistant prefix).
  Future<Result<int>> countPromptTokens(String user, {String? systemPrompt});

  /// Context window (n_ctx) the loaded model runs with.
  Future<Result<int>> contextWindow();
}

/// Local LLM inference (llama.cpp behind the native bridge).
abstract interface class LlmEngine {
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  });
}
