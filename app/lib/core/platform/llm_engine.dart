import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// A single prompt execution.
class LlmRequest {
  const LlmRequest({required this.prompt, this.grammar, this.maxTokens = 1024});

  final String prompt;

  /// Optional GBNF grammar constraining the output.
  final String? grammar;
  final int maxTokens;
}

/// Local LLM inference (llama.cpp behind the native bridge).
abstract interface class LlmEngine {
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  });
}
