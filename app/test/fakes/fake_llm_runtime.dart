import 'dart:async';

import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';

/// Scripted [LlmRuntime]: sessions stream [chunks] one per [perChunk];
/// [gpuStatus] / [cpuStatus] decide how a run ends when not cancelled.
class FakeLlmRuntime implements LlmRuntime {
  FakeLlmRuntime({
    this.chunks = const ['Hel', 'lo', '!'],
    this.perChunk = const Duration(milliseconds: 5),
    this.gpuStatus = LlmRunStatus.ok,
    this.cpuStatus = LlmRunStatus.ok,
    this.loadError,
  });

  List<String> chunks;
  Duration perChunk;
  LlmRunStatus gpuStatus;
  LlmRunStatus cpuStatus;
  int? loadError;
  final List<LlmBackendChoice> loads = [];
  final List<FakeLlmSession> sessions = [];

  /// Called when a run has emitted its first chunk.
  void Function(FakeLlmRun run)? onFirstChunk;

  @override
  Future<LlmSession> load(
    String modelPath,
    LlmBackendChoice choice, {
    required int contextSize,
  }) async {
    loads.add(choice);
    if (loadError case final code?) throw LlmLoadException(code);
    final s = FakeLlmSession(
      this,
      usedGpu: choice.useGpu,
      contextSize: contextSize,
    );
    sessions.add(s);
    return s;
  }
}

class FakeLlmSession implements LlmSession {
  FakeLlmSession(this._rt, {required this.usedGpu, required this.contextSize});

  final FakeLlmRuntime _rt;
  @override
  final bool usedGpu;
  @override
  final int contextSize;
  bool disposed = false;
  final List<String> prompts = [];
  final List<String?> grammars = [];
  final List<bool> reusePrefix = [];

  @override
  int countTokens(String text) => text.split(' ').length;

  @override
  String applyChatTemplate(List<(String, String)> messages) =>
      messages.map((m) => '<${m.$1}>${m.$2}').join();

  @override
  LlmRun generate(
    String prompt, {
    required LlmSampling sampling,
    required int maxTokens,
    String? grammar,
    bool reusePrefix = false,
  }) {
    if (grammar == 'bad') {
      throw const LlmRequestException(LlmRejection.invalidGrammar);
    }
    prompts.add(prompt);
    grammars.add(grammar);
    this.reusePrefix.add(reusePrefix);
    final run = FakeLlmRun(
      _rt.chunks,
      _rt.perChunk,
      usedGpu ? _rt.gpuStatus : _rt.cpuStatus,
      _rt.onFirstChunk,
      gpu: usedGpu,
    );
    unawaited(run._start());
    return run;
  }

  @override
  void dispose() => disposed = true;
}

class FakeLlmRun implements LlmRun {
  FakeLlmRun(
    this._chunks,
    this._per,
    this._end,
    this._onFirst, {
    required this.gpu,
  });

  final List<String> _chunks;
  final Duration _per;
  final LlmRunStatus _end;
  final bool gpu;
  final void Function(FakeLlmRun)? _onFirst;
  final _text = StreamController<String>();
  final _done = Completer<LlmRunStats>();
  bool cancelled = false;
  DateTime? cancelledAt;

  @override
  Stream<String> get text => _text.stream;

  @override
  Future<LlmRunStats> get done => _done.future;

  @override
  void cancel() {
    cancelled = true;
    cancelledAt ??= DateTime.now();
  }

  Future<void> _start() async {
    var n = 0;
    var status = _end;
    for (final c in _chunks) {
      await Future<void>.delayed(_per);
      if (cancelled) {
        status = LlmRunStatus.cancelled;
        break;
      }
      _text.add(c);
      n++;
      if (n == 1) _onFirst?.call(this);
    }
    if (cancelled) status = LlmRunStatus.cancelled;
    await _text.close();
    _done.complete(
      LlmRunStats(
        status: status,
        nativeCode: status == LlmRunStatus.ok ? 0 : -6,
        promptTokens: 10,
        generatedTokens: n,
        prefill: const Duration(milliseconds: 1),
        decode: Duration(milliseconds: n),
        usedGpu: gpu,
      ),
    );
  }
}
