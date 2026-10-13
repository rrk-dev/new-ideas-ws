import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';

/// [LlmEngine] over a native [LlmRuntime] (LLM-04).
///
/// - Loads lazily on the first request; [unload] frees the model (the
///   pipeline unloads between steps — never STT and LLM together, LLM-07).
/// - Streams text through `onToken`; a [CancelToken] is polled every
///   [pollInterval] and forwarded to the native cancel (stops < 500 ms).
/// - **GPU → CPU recovery**: when the app is backgrounded on iOS
///   ([onBackgrounded]) a running GPU generation is stopped and the request
///   is re-run from the start on a CPU session; a mid-run `VV_E_BACKEND`
///   from a GPU session (e.g. iOS refused GPU work) does the same once.
///   The pipeline's checkpoint is the step boundary, so a restart re-runs
///   only this prompt; [onRestart] tells streaming UIs to clear partial text.
final class LlmService implements LlmEngine {
  LlmService({
    required this.runtime,
    required this.modelPath,
    required this.backend,
    this.contextSize = 4096,
    this.pollInterval = const Duration(milliseconds: 50),
    this.onStats,
    this.onRestart,
  });

  final LlmRuntime runtime;

  /// Requested backend for the next load (platform policy + allowlist).
  final LlmBackendChoice Function() backend;
  final String modelPath;
  final int contextSize;
  final Duration pollInterval;

  /// Per-run stats (FND-07 metrics: prefill/decode tok/s, token counts).
  final void Function(LlmRunStats stats)? onStats;

  /// A run is being restarted on the CPU (partial text is discarded).
  final void Function()? onRestart;

  LlmSession? _session;
  Future<LlmSession>? _loading;
  LlmRun? _active;
  bool _forceCpu = false;
  bool _internalCancel = false;

  bool get isLoaded => _session != null;

  /// Whether the loaded session runs on the GPU (null when unloaded).
  bool? get usesGpu => _session?.usedGpu;

  /// Loads the model now (otherwise the first request does).
  Future<void> load() async {
    await _ensureSession();
  }

  /// Frees the model; a running generation is cancelled first.
  void unload() {
    _active?.cancel();
    _session?.dispose();
    _session = null;
  }

  /// The app moved to the background: iOS forbids GPU work from now on.
  void onBackgrounded() {
    final s = _session;
    if (s == null || !s.usedGpu) return;
    _forceCpu = true;
    if (_active != null) {
      _internalCancel = true;
      _active!.cancel();
    }
  }

  /// Back in the foreground: the next load may use the GPU again.
  void onForegrounded() => _forceCpu = false;

  Future<LlmSession> _ensureSession() async {
    if (_loading != null) return await _loading!;
    final want = _forceCpu
        ? const LlmBackendChoice(useGpu: false, reason: 'forced-cpu')
        : backend();
    final current = _session;
    if (current != null && !(current.usedGpu && !want.useGpu)) return current;
    current?.dispose();
    _session = null;
    final loading = runtime.load(modelPath, want, contextSize: contextSize);
    _loading = loading;
    try {
      return _session = await loading;
    } finally {
      _loading = null;
    }
  }

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    for (var attempt = 0; attempt < 2; attempt++) {
      final LlmSession session;
      try {
        session = await _ensureSession();
      } on Object catch (e) {
        return Err(_loadFailure(e));
      }
      final String prompt;
      try {
        prompt = request.templated
            ? request.prompt
            : session.applyChatTemplate([
                if (request.systemPrompt case final s?) ('system', s),
                ('user', request.prompt),
              ]);
      } on LlmRequestException {
        return const Err(NativeFailure(-1, 'llm: unsupported chat template'));
      }
      final LlmRun run;
      try {
        run = session.generate(
          prompt,
          sampling: request.sampling,
          maxTokens: request.maxTokens,
          grammar: request.grammar,
        );
      } on LlmRequestException catch (e) {
        return Err(
          e.reason == LlmRejection.busy
              ? const NativeFailure(-7, 'llm: busy')
              : const NativeFailure(-1, 'llm: invalid grammar'),
        );
      }
      _active = run;
      _internalCancel = false;
      final poll = Timer.periodic(pollInterval, (_) {
        if (cancel?.isCancelled ?? false) run.cancel();
      });
      final out = StringBuffer();
      final textDone = Completer<void>();
      final sub = run.text.listen(
        (t) {
          out.write(t);
          onToken?.call(t);
        },
        onDone: textDone.complete,
        onError: (Object _) {},
      );
      final LlmRunStats stats;
      try {
        stats = await run.done;
        await textDone.future; // the stream closes after the last chunk
      } finally {
        poll.cancel();
        await sub.cancel();
        _active = null;
      }
      onStats?.call(stats);
      final userCancelled = cancel?.isCancelled ?? false;
      switch (stats.status) {
        case LlmRunStatus.ok:
          return Ok(out.toString());
        case LlmRunStatus.cancelled when _internalCancel && !userCancelled:
        case LlmRunStatus.backend when stats.usedGpu && attempt == 0:
          _internalCancel = false;
          _forceCpu = true;
          onRestart?.call();
          continue;
        case LlmRunStatus.cancelled:
          return const Err(CancelledFailure());
        case LlmRunStatus.outOfMemory:
          return const Err(OutOfMemoryFailure());
        case LlmRunStatus.invalid:
          return Err(NativeFailure(stats.nativeCode, 'llm: invalid request'));
        case LlmRunStatus.backend:
        case LlmRunStatus.busy:
        case LlmRunStatus.other:
          return Err(NativeFailure(stats.nativeCode, 'llm: generation failed'));
      }
    }
    return const Err(NativeFailure(-6, 'llm: generation failed after retry'));
  }

  Failure _loadFailure(Object e) => switch (e) {
    LlmLoadException(:final code) when code == -3 => const OutOfMemoryFailure(),
    LlmLoadException(:final code) => NativeFailure(code, 'llm: model load'),
    _ => UnexpectedFailure(e.runtimeType.toString()),
  };
}

/// Thrown by [LlmRuntime.load] with the native `VV_E_*` code.
final class LlmLoadException implements Exception {
  const LlmLoadException(this.code);

  final int code;

  @override
  String toString() => 'LlmLoadException($code)';
}
