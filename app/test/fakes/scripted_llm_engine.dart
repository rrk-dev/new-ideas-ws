import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';

/// [LlmEngine] returning one scripted response per call, in order
/// (a [Failure] entry is returned as `Err`). Records every request.
class ScriptedLlmEngine implements LlmEngine {
  ScriptedLlmEngine(this.responses);

  final List<Object> responses;
  final List<LlmRequest> requests = [];

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    requests.add(request);
    if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    final r = responses[requests.length - 1];
    if (r is Failure) return Err(r);
    onToken?.call(r as String);
    return Ok(r as String);
  }
}
