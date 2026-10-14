import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

/// A `[start, end)` slice of a 16 kHz PCM16 WAV file; `endMs < 0` = to EOF.
class VvAudioRange {
  const VvAudioRange(this.path, {this.startMs = 0, this.endMs = -1});

  final String path;
  final int startMs;
  final int endMs;
}

/// Decoding parameters (`vv_stt_params`). Defaults match
/// `vv_stt_default_params()` and the vv-whisper-stt defaults table.
class VvSttParams {
  const VvSttParams({
    this.language = 'en',
    this.nThreads = 0,
    this.beamSize = 1,
    this.temperature = 0,
    this.temperatureInc = 0.2,
    this.initialPrompt,
    this.carryInitialPrompt = true,
    this.noContext = true,
    this.tokenTimestamps = false,
    this.suppressNonSpeech = true,
    this.entropyThreshold = 2.4,
    this.logprobThreshold = -1,
    this.noSpeechThreshold = 0.6,
    this.vadModelPath,
    this.vadThreshold = 0.5,
    this.vadMinSpeechMs = 250,
    this.vadMinSilenceMs = 500,
    this.vadSpeechPadMs = 200,
  });

  /// `en`, `de`, … or `auto`.
  final String language;

  /// `<= 0`: performance cores capped at 4.
  final int nThreads;

  /// `<= 1`: greedy.
  final int beamSize;
  final double temperature;

  /// 0 disables temperature fallback.
  final double temperatureInc;

  /// Vocabulary hints (product/team names) — never logged.
  final String? initialPrompt;
  final bool carryInitialPrompt;
  final bool noContext;
  final bool tokenTimestamps;
  final bool suppressNonSpeech;
  final double entropyThreshold;
  final double logprobThreshold;
  final double noSpeechThreshold;

  /// AUD-03: ggml Silero VAD model; when set, whisper.cpp skips silence
  /// before decoding and maps every time back to the original audio.
  final String? vadModelPath;
  final double vadThreshold;
  final int vadMinSpeechMs;
  final int vadMinSilenceMs;
  final int vadSpeechPadMs;
}

/// One token with probability (token timestamps only).
class VvSttToken {
  const VvSttToken(this.text, this.p, this.t0Ms, this.t1Ms);

  final String text;
  final double p;
  final int t0Ms;
  final int t1Ms;
}

/// Events of one transcription job, in order: any number of
/// [VvSttProgress] / [VvSttSegment], then exactly one [VvSttDone].
sealed class VvSttEvent {
  const VvSttEvent();
}

final class VvSttProgress extends VvSttEvent {
  const VvSttProgress(this.percent);

  final int percent;
}

final class VvSttSegment extends VvSttEvent {
  const VvSttSegment({
    required this.index,
    required this.t0Ms,
    required this.t1Ms,
    required this.t0Range,
    required this.t0SrcMs,
    required this.t1Range,
    required this.t1SrcMs,
    required this.avgLogprob,
    required this.noSpeechProb,
    required this.text,
    this.tokens = const [],
  });

  final int index;

  /// Position in the concatenated input.
  final int t0Ms;
  final int t1Ms;

  /// Range index + time inside that range's file.
  final int t0Range;
  final int t0SrcMs;
  final int t1Range;
  final int t1SrcMs;
  final double avgLogprob;
  final double noSpeechProb;
  final String text;
  final List<VvSttToken> tokens;
}

final class VvSttDone extends VvSttEvent {
  const VvSttDone(this.status, this.audioMs, this.processMs);

  /// `VV_OK` or a negative `VV_E_*` code.
  final int status;
  final int audioMs;
  final int processMs;
}

/// A bridge call failed synchronously.
class VvSttException implements Exception {
  const VvSttException(this.code, this.operation);

  final int code;
  final String operation;

  @override
  String toString() => 'VvSttException($operation: $code)';
}

/// whisper.cpp model behind `vv_stt_*`. Model load and destroy run on a
/// helper isolate; transcription runs on a native worker thread with
/// `NativeCallable.listener` callbacks — nothing heavy runs on the calling
/// (UI) isolate. Call [dispose] explicitly (models are large; no GC-driven
/// unload).
class VvWhisper {
  VvWhisper._(this._b, this._h, this._hostPath);

  final VvBindings _b;
  final Pointer<vv_stt> _h;
  final String? _hostPath;
  _Job? _job;
  bool _disposed = false;

  /// Loads [modelPath]. [useGpu] false = CPU backend only (background).
  static Future<VvWhisper> load(
    String modelPath, {
    bool useGpu = true,
    bool flashAttn = false,
    String? hostPath,
  }) async {
    final (rc, address) = await Isolate.run(() {
      final b = VvBindings(openVvNative(hostPath: hostPath));
      return using((arena) {
        final ip = arena<vv_stt_init_params>()
          ..ref = b.vv_stt_default_init_params();
        ip.ref
          ..use_gpu = useGpu ? 1 : 0
          ..flash_attn = flashAttn ? 1 : 0;
        final out = arena<Pointer<vv_stt>>();
        final rc = b.vv_stt_create(
          modelPath.toNativeUtf8(allocator: arena).cast(),
          ip,
          out,
        );
        return (rc, out.value.address);
      });
    });
    if (rc != VV_OK) throw VvSttException(rc, 'create');
    return VvWhisper._(
      VvBindings(openVvNative(hostPath: hostPath)),
      Pointer<vv_stt>.fromAddress(address),
      hostPath,
    );
  }

  /// Whether a job is running.
  bool get busy => _job != null;

  /// Transcribes the concatenation of [ranges]. The stream ends after the
  /// [VvSttDone] event. Cancelling the subscription cancels the job.
  /// Throws [VvSttException] (`VV_E_BUSY`, `VV_E_INVALID_ARG`) when the job
  /// cannot start.
  Stream<VvSttEvent> transcribe(
    List<VvAudioRange> ranges, {
    VvSttParams params = const VvSttParams(),
  }) {
    if (_disposed) throw StateError('VvWhisper disposed');
    if (_job != null) throw const VvSttException(VV_E_BUSY, 'transcribe');
    final job = _Job(this);
    final rc = using((arena) {
      final prompt = params.initialPrompt;
      final p = arena<vv_stt_params>()..ref = _b.vv_stt_default_params();
      p.ref
        ..language = params.language.toNativeUtf8(allocator: arena).cast()
        ..n_threads = params.nThreads
        ..beam_size = params.beamSize
        ..temperature = params.temperature
        ..temperature_inc = params.temperatureInc
        ..initial_prompt = prompt == null || prompt.isEmpty
            ? nullptr
            : prompt.toNativeUtf8(allocator: arena).cast()
        ..carry_initial_prompt = params.carryInitialPrompt ? 1 : 0
        ..no_context = params.noContext ? 1 : 0
        ..token_timestamps = params.tokenTimestamps ? 1 : 0
        ..suppress_nst = params.suppressNonSpeech ? 1 : 0
        ..entropy_thold = params.entropyThreshold
        ..logprob_thold = params.logprobThreshold
        ..no_speech_thold = params.noSpeechThreshold
        ..vad_model_path = params.vadModelPath == null
            ? nullptr
            : params.vadModelPath!.toNativeUtf8(allocator: arena).cast()
        ..vad_threshold = params.vadThreshold
        ..vad_min_speech_ms = params.vadMinSpeechMs
        ..vad_min_silence_ms = params.vadMinSilenceMs
        ..vad_speech_pad_ms = params.vadSpeechPadMs;
      final rs = arena<vv_audio_range>(ranges.isEmpty ? 1 : ranges.length);
      for (var i = 0; i < ranges.length; i++) {
        rs[i].path = ranges[i].path.toNativeUtf8(allocator: arena).cast();
        rs[i].start_ms = ranges[i].startMs;
        rs[i].end_ms = ranges[i].endMs;
      }
      // Native code copies every string/array before returning.
      return _b.vv_stt_transcribe_ranges(
        _h,
        rs,
        ranges.length,
        p,
        job.callbacks(arena),
        nullptr,
      );
    });
    if (rc != VV_OK) {
      job.close();
      throw VvSttException(rc, 'transcribe');
    }
    _job = job;
    return job.controller.stream;
  }

  /// Requests cancellation of the running job (returns immediately; the
  /// stream then ends with `VvSttDone(VV_E_CANCELLED)`).
  void cancel() {
    if (_job != null && !_disposed) _b.vv_stt_cancel(_h);
  }

  /// Cancels a running job, waits for it to finish and frees the model.
  Future<void> dispose() async {
    if (_disposed) return;
    final job = _job;
    if (job != null) {
      _b.vv_stt_cancel(_h);
      await job.finished.future;
    }
    _disposed = true;
    final address = _h.address;
    final hostPath = _hostPath;
    await Isolate.run(() {
      VvBindings(openVvNative(hostPath: hostPath))
          .vv_stt_destroy(Pointer<vv_stt>.fromAddress(address));
    });
  }

  void _finished(_Job job) {
    if (identical(_job, job)) _job = null;
  }
}

class _Job {
  _Job(this.owner) {
    controller = StreamController<VvSttEvent>(
      onCancel: () {
        // Subscriber gone: stop native work; callbacks still drain to close().
        if (!finished.isCompleted) owner.cancel();
      },
    );
    progress = NativeCallable<vv_stt_progress_cbFunction>.listener(_onProgress);
    segment = NativeCallable<vv_stt_segment_cbFunction>.listener(_onSegment);
    done = NativeCallable<vv_stt_done_cbFunction>.listener(_onDone);
  }

  final VvWhisper owner;
  late final StreamController<VvSttEvent> controller;
  late final NativeCallable<vv_stt_progress_cbFunction> progress;
  late final NativeCallable<vv_stt_segment_cbFunction> segment;
  late final NativeCallable<vv_stt_done_cbFunction> done;
  final Completer<void> finished = Completer<void>();

  vv_stt_callbacks callbacks(Allocator arena) {
    final c = arena<vv_stt_callbacks>();
    c.ref.on_progress = progress.nativeFunction;
    c.ref.on_segment = segment.nativeFunction;
    c.ref.on_done = done.nativeFunction;
    return c.ref;
  }

  void _onProgress(Pointer<Void> _, int percent) {
    if (!controller.isClosed) controller.add(VvSttProgress(percent));
  }

  void _onSegment(Pointer<Void> _, Pointer<vv_stt_segment> seg) {
    // Copy, then free: the payload is ours (vv_whisper.h ownership rule).
    final s = seg.ref;
    final tokens = <VvSttToken>[
      for (var i = 0; i < s.n_tokens; i++)
        VvSttToken(
          s.tokens[i].text.cast<Utf8>().toDartString(),
          s.tokens[i].p,
          s.tokens[i].t0_ms,
          s.tokens[i].t1_ms,
        ),
    ];
    final event = VvSttSegment(
      index: s.index,
      t0Ms: s.t0_ms,
      t1Ms: s.t1_ms,
      t0Range: s.t0_range,
      t0SrcMs: s.t0_src_ms,
      t1Range: s.t1_range,
      t1SrcMs: s.t1_src_ms,
      avgLogprob: s.avg_logprob,
      noSpeechProb: s.no_speech_prob,
      text: s.text.cast<Utf8>().toDartString(),
      tokens: tokens,
    );
    owner._b.vv_stt_free_segment(seg);
    if (!controller.isClosed) controller.add(event);
    _receivedSegments++;
    _maybeFinish();
  }

  void _onDone(
    Pointer<Void> _,
    int status,
    int audioMs,
    int processMs,
    int nSegments,
  ) {
    // Each callable has its own port: wait until every segment the native
    // side reported has arrived before ending the stream.
    _pendingDone = VvSttDone(status, audioMs, processMs);
    _expectedSegments = nSegments;
    _maybeFinish();
  }

  VvSttDone? _pendingDone;
  int _expectedSegments = -1;
  int _receivedSegments = 0;

  void _maybeFinish() {
    final doneEvent = _pendingDone;
    if (doneEvent == null || _receivedSegments < _expectedSegments) return;
    _pendingDone = null;
    if (!controller.isClosed) controller.add(doneEvent);
    close();
    owner._finished(this);
    if (!finished.isCompleted) finished.complete();
  }

  void close() {
    progress.close();
    segment.close();
    done.close();
    if (!controller.isClosed) unawaited(controller.close());
  }
}
