import 'dart:async';
import 'dart:io';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/native_failures.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vv_native/vv_native.dart';

/// Resolves the installed model file (MDL-02), or null when not installed.
typedef ModelPathResolver = Future<String?> Function();

/// [SttEngine] backed by whisper.cpp through `vv_stt_*` (STT-03).
///
/// - Model load/unload run on a helper isolate, decoding on a native worker
///   thread: the calling isolate only receives events.
/// - The model stays loaded across consecutive calls (chunks of one job)
///   and is freed after [idleUnload] without a new call, or immediately by
///   [unload] (the pipeline's `HeavyModelGate` calls it before the LLM step:
///   STT and LLM are never resident together).
/// - [useGpu] is asked before each call (backend policy: background → CPU);
///   a change reloads the model with the other backend.
/// - Calls are serialised (one whisper job per context).
class WhisperSttEngine implements SttEngine {
  WhisperSttEngine({
    required this.modelId,
    required this.modelPath,
    bool Function()? useGpu,
    this.idleUnload = const Duration(seconds: 5),
    this.cancelPoll = const Duration(milliseconds: 50),
    this.hostLibPath,
  }) : useGpu = useGpu ?? _always;

  static bool _always() => true;

  /// Catalog id of the model (for [ModelMissingFailure]).
  final String modelId;
  final ModelPathResolver modelPath;
  final bool Function() useGpu;
  final Duration idleUnload;

  /// How often the [CancelToken] is checked (cancel latency budget is 1 s).
  final Duration cancelPoll;

  /// Host tests/tools only: path of `libvv_native` outside an app bundle.
  final String? hostLibPath;

  VvWhisper? _whisper;
  bool? _loadedWithGpu;
  Timer? _idle;
  Future<void> _queue = Future<void>.value();

  /// Whether a model is currently resident.
  bool get loaded => _whisper != null;

  @override
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  }) {
    final run = _queue.then(
      (_) => _transcribe(audioPath, cancel, onProgress, onSegment, options),
    );
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<Result<Transcript>> _transcribe(
    String audioPath,
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options,
  ) async {
    _idle?.cancel();
    if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    final VvWhisper whisper;
    switch (await _acquire()) {
      case Ok(:final value):
        whisper = value;
      case Err(:final failure):
        return Err(failure);
    }
    final segments = <TranscriptSegment>[];
    VvSttDone? done;
    final poll = Timer.periodic(cancelPoll, (_) {
      if (cancel?.isCancelled ?? false) whisper.cancel();
    });
    try {
      final events = whisper.transcribe([
        VvAudioRange(audioPath),
      ], params: _params(options));
      await for (final e in events) {
        switch (e) {
          case VvSttProgress(:final percent):
            onProgress?.call(percent / 100);
          case final VvSttSegment s:
            final seg = _segment(s);
            segments.add(seg);
            onSegment?.call(seg);
          case final VvSttDone d:
            done = d;
        }
      }
    } on VvSttException catch (e) {
      return Err(failureFromVvCode(e.code, operation: 'stt'));
    } finally {
      poll.cancel();
      _scheduleIdleUnload();
    }
    if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    final status = done?.status ?? VV_E_INTERNAL;
    if (status != VV_OK) {
      return Err(failureFromVvCode(status, operation: 'stt'));
    }
    return Ok(Transcript(segments));
  }

  /// Frees the model now (idempotent). Waits for a running job to cancel.
  Future<void> unload() async {
    _idle?.cancel();
    final w = _whisper;
    _whisper = null;
    _loadedWithGpu = null;
    await w?.dispose();
  }

  Future<Result<VvWhisper>> _acquire() async {
    final gpu = useGpu();
    final current = _whisper;
    if (current != null && _loadedWithGpu == gpu) return Ok(current);
    await unload();
    final path = await modelPath();
    if (path == null || !File(path).existsSync()) {
      return Err(ModelMissingFailure(modelId));
    }
    try {
      final w = await VvWhisper.load(path, useGpu: gpu, hostPath: hostLibPath);
      _whisper = w;
      _loadedWithGpu = gpu;
      return Ok(w);
    } on VvSttException catch (e) {
      return Err(failureFromVvCode(e.code, operation: 'stt load'));
    }
  }

  void _scheduleIdleUnload() {
    _idle?.cancel();
    _idle = Timer(idleUnload, () => unawaited(unload()));
  }

  static VvSttParams _params(SttOptions o) => VvSttParams(
    language: o.language,
    nThreads: o.threads,
    beamSize: o.beamSize,
    temperatureInc: o.temperatureFallback ? 0.2 : 0,
    initialPrompt: o.initialPrompt,
    tokenTimestamps: o.tokenTimestamps,
  );

  static TranscriptSegment _segment(VvSttSegment s) => TranscriptSegment(
    start: Duration(milliseconds: s.t0SrcMs),
    end: Duration(milliseconds: s.t1SrcMs),
    text: s.text.trim(),
    avgLogprob: s.avgLogprob,
    noSpeechProb: s.noSpeechProb,
    tokens: [
      for (final t in s.tokens)
        TranscriptToken(
          text: t.text,
          p: t.p,
          start: t.t0Ms < 0 ? null : Duration(milliseconds: t.t0Ms),
          end: t.t1Ms < 0 ? null : Duration(milliseconds: t.t1Ms),
        ),
    ],
  );
}
