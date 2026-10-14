import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';

/// How a native run ended (maps `VV_*` codes).
enum LlmRunStatus { ok, cancelled, invalid, backend, outOfMemory, busy, other }

/// Stats of one run (content-free; FND-07 metrics).
@immutable
final class LlmRunStats {
  const LlmRunStats({
    required this.status,
    required this.nativeCode,
    required this.promptTokens,
    required this.generatedTokens,
    required this.prefill,
    required this.decode,
    required this.usedGpu,
  });

  final LlmRunStatus status;
  final int nativeCode;
  final int promptTokens;
  final int generatedTokens;
  final Duration prefill;
  final Duration decode;
  final bool usedGpu;

  double get decodeTokensPerSecond => decode.inMicroseconds == 0
      ? 0
      : generatedTokens * 1e6 / decode.inMicroseconds;
}

/// Why a session rejected a request synchronously.
enum LlmRejection { unsupportedTemplate, invalidGrammar, busy }

/// Thrown by [LlmSession] for requests it cannot start.
final class LlmRequestException implements Exception {
  const LlmRequestException(this.reason);

  final LlmRejection reason;

  @override
  String toString() => 'LlmRequestException(${reason.name})';
}

/// A running generation.
abstract interface class LlmRun {
  Stream<String> get text;
  Future<LlmRunStats> get done;
  void cancel();
}

/// One loaded model (native handle). Owned by `LlmService`.
abstract interface class LlmSession {
  bool get usedGpu;
  int get contextSize;
  int countTokens(String text);

  /// Throws [LlmRequestException] (`unsupportedTemplate`).
  String applyChatTemplate(List<(String, String)> messages);

  /// Throws [LlmRequestException] (`invalidGrammar`, `busy`).
  LlmRun generate(
    String prompt, {
    required LlmSampling sampling,
    required int maxTokens,
    String? grammar,
  });

  /// Frees the model; idempotent.
  void dispose();
}

/// Loads sessions (real: FFI over `vv_native`; tests: fakes).
abstract interface class LlmRuntime {
  Future<LlmSession> load(
    String modelPath,
    LlmBackendChoice choice, {
    required int contextSize,
  });
}
