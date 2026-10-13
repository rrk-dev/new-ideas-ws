// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';

/// Scripted [LlmEngine]: streams [tokens] one per [perToken].
class FakeLlmEngine implements LlmEngine {
  FakeLlmEngine({
    this.tokens = const ['{', '"ok"', ':true', '}'],
    this.perToken = Duration.zero,
  });

  final List<String> tokens;
  final Duration perToken;
  Failure? _failure;
  final List<LlmRequest> requests = [];

  void failWith(Failure failure) => _failure = failure;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    requests.add(request);
    if (_failure case final failure?) return Err(failure);
    final out = StringBuffer();
    for (final token in tokens.take(request.maxTokens)) {
      if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
      await Future<void>.delayed(perToken);
      out.write(token);
      onToken?.call(token);
    }
    return Ok(out.toString());
  }
}
