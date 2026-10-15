import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';

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
final class LlmService implements LlmEngine, LlmTokenizer {
  LlmService({
    required this.runtime,
    required this.modelPath,
    required this.backend,
    this.contextSize = 4096,
    this.pollInterval = const Duration(milliseconds: 50),
    this.onStats,
    this.onRestart,
    this.loadGate,
    this.onBeforeLoad,
  }) : _contextSize = contextSize;

  final LlmRuntime runtime;

  /// Requested backend for the next load (platform policy + allowlist).
  final LlmBackendChoice Function() backend;
  final String modelPath;

  /// Requested context; [onMemoryPressure] lowers [effectiveContextSize].
  final int contextSize;
  int _contextSize;
  final Duration pollInterval;

  /// Pre-load memory check (LLM-07 `planLlmLoad`): returns the context to
  /// load with, or `Err(OutOfMemoryFailure)` to refuse the load.
  final Result<int> Function(int requestedContext)? loadGate;

  /// Awaited right before a model load (LLM-07 `ModelResidency.acquire`:
  /// unloads STT first and waits for it — never STT and LLM together). A
  /// throw (e.g. `ModelResidencyException`) refuses the load.
  final FutureOr<void> Function()? onBeforeLoad;

  /// Per-run stats (FND-07 metrics: prefill/decode tok/s, token counts).
  final void Function(LlmRunStats stats)? onStats;

  /// A run is being restarted on the CPU (partial text is discarded).
  final void Function()? onRestart;

  LlmSession? _session;
  Future<LlmSession>? _loading;
  LlmRun? _active;
  bool _forceCpu = false;
  bool _internalCancel = false;
  bool _pressureCancel = false;

  /// Context the next load uses (reduced after memory pressure).
  int get effectiveContextSize => _contextSize;

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
  ///
  /// Always forces CPU for the next load — also when nothing is loaded yet
  /// or a GPU load is still in flight: [_ensureSession] discards a GPU
  /// session that finishes loading after this call before any generation
  /// starts on it (LLM-04 rework: background-during-load race).
  void onBackgrounded() {
    _forceCpu = true;
    final s = _session;
    if (s == null || !s.usedGpu) return;
    if (_active != null) {
      _internalCancel = true;
      _active!.cancel();
    }
  }

  /// Back in the foreground: the next load may use the GPU again.
  void onForegrounded() => _forceCpu = false;

  /// OS memory warning (Flutter `didHaveMemoryPressure`, i.e. iOS
  /// `didReceiveMemoryWarning` / Android `onTrimMemory`/`onLowMemory`):
  /// stop at the next token, unload, and use half the context (≥ 2048) on
  /// the next load. The running request returns `OutOfMemoryFailure` so the
  /// pipeline retries from its checkpoint (smaller ctx / map-reduce, LLM-06).
  void onMemoryPressure() {
    if (_contextSize > 2048) {
      _contextSize = (_contextSize ~/ 2).clamp(2048, _contextSize);
    }
    if (_active != null) {
      _pressureCancel = true;
      _active!.cancel();
    } else {
      unload();
    }
  }

  /// A session that may run work now: never a GPU session while
  /// backgrounded. The app can be backgrounded while the (asynchronous)
  /// load is in flight; such a GPU session is disposed unused and the model
  /// is reloaded on the CPU — every caller that awaited the same load
  /// re-checks, so no caller ever receives it.
  Future<LlmSession> _ensureSession() async {
    while (true) {
      final s = await _ensureSessionOnce();
      if (!(s.usedGpu && _forceCpu)) return s;
      if (identical(_session, s)) {
        s.dispose();
        _session = null;
      }
    }
  }

  Future<LlmSession> _ensureSessionOnce() async {
    if (_loading != null) return await _loading!;
    final want = _forceCpu
        ? const LlmBackendChoice(useGpu: false, reason: 'forced-cpu')
        : backend();
    final current = _session;
    if (current != null && !(current.usedGpu && !want.useGpu)) return current;
    current?.dispose();
    _session = null;
    var ctx = _contextSize;
    if (loadGate case final gate?) {
      switch (gate(ctx)) {
        case Ok(:final value):
          ctx = value;
        case Err(:final failure):
          throw _GateRefused(failure);
      }
    }
    // `_loading` covers the residency wait too, so a concurrent request
    // joins this load instead of starting a second one.
    final loading = _load(want, ctx);
    _loading = loading;
    try {
      return _session = await loading;
    } finally {
      _loading = null;
    }
  }

  Future<LlmSession> _load(LlmBackendChoice want, int ctx) async {
    // Awaited: the other model's (asynchronous) disposal must have finished
    // before the native load starts (LLM-07 rework).
    await onBeforeLoad?.call();
    // Backgrounded while waiting (iOS forbids GPU work): load on the CPU.
    final choice = _forceCpu && want.useGpu
        ? const LlmBackendChoice(useGpu: false, reason: 'forced-cpu')
        : want;
    return await runtime.load(modelPath, choice, contextSize: ctx);
  }

  @override
  Future<Result<int>> countTokens(String text) =>
      _withSession((s) => s.countTokens(text));

  @override
  Future<Result<int>> countPromptTokens(String user, {String? systemPrompt}) =>
      _withSession(
        (s) => s.countTokens(
          s.applyChatTemplate([
            if (systemPrompt case final sys?) ('system', sys),
            ('user', user),
          ]),
        ),
      );

  @override
  Future<Result<int>> contextWindow() => _withSession((s) => s.contextSize);

  Future<Result<int>> _withSession(int Function(LlmSession s) f) async {
    try {
      return Ok(f(await _ensureSession()));
    } on _GateRefused catch (e) {
      return Err(e.failure);
    } on LlmRequestException {
      return const Err(NativeFailure(-1, 'llm: unsupported chat template'));
    } on Object catch (e) {
      return Err(_loadFailure(e));
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
      } on _GateRefused catch (e) {
        return Err(e.failure);
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
          reusePrefix: request.reusePrefix,
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
      _pressureCancel = false;
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
      if (_pressureCancel && stats.status == LlmRunStatus.cancelled) {
        _pressureCancel = false;
        unload();
        return const Err(OutOfMemoryFailure());
      }
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
    // The other model could not be freed: retry later (classified
    // retryable, like an OOM) — never load on top of it.
    ModelResidencyException() => const OutOfMemoryFailure(),
    _ => UnexpectedFailure(e.runtimeType.toString()),
  };
}

final class _GateRefused implements Exception {
  const _GateRefused(this.failure);

  final Failure failure;
}

/// Thrown by [LlmRuntime.load] with the native `VV_E_*` code.
final class LlmLoadException implements Exception {
  const LlmLoadException(this.code);

  final int code;

  @override
  String toString() => 'LlmLoadException($code)';
}
