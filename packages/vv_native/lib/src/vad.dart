import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';
import 'package:vv_native/src/whisper.dart' show VvAudioRange;

/// Silero VAD parameters (`vv_vad_params`, AUD-03). Defaults =
/// `vv_vad_default_params()` = vv-audio-capture (min speech 250 ms, min
/// silence 500 ms, pad 200 ms).
class VvVadParams {
  const VvVadParams({
    this.threshold = 0.5,
    this.minSpeechMs = 250,
    this.minSilenceMs = 500,
    this.speechPadMs = 200,
    this.maxSpeechS = 0,
    this.nThreads = 1,
  });

  final double threshold;
  final int minSpeechMs;
  final int minSilenceMs;
  final int speechPadMs;

  /// Split longer segments; `<= 0` = no limit.
  final double maxSpeechS;
  final int nThreads;
}

/// One speech span in ms on the analysed timeline.
class VvSpeechSegment {
  const VvSpeechSegment(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  @override
  String toString() => 'VvSpeechSegment($startMs, $endMs)';
}

/// Result of one [VvVad.feed]: 32 ms windows completed and how many were
/// speech.
class VvVadFeed {
  const VvVadFeed(this.windows, this.speechWindows, this.maxProb);

  static const windowMs = 32;

  final int windows;
  final int speechWindows;

  /// Highest probability, -1 when [windows] is 0.
  final double maxProb;
}

class VvVadException implements Exception {
  const VvVadException(this.code, this.operation);

  final int code;
  final String operation;

  @override
  String toString() => 'VvVadException($operation: $code)';
}

/// whisper.cpp's Silero VAD behind `vv_vad_*`. **Synchronous**: create it
/// and call it on a background isolate (the pipeline worker, or
/// [VvVadStream]) — never on the UI isolate. One caller at a time.
class VvVad {
  VvVad._(this._b, this._h);

  /// Loads the ggml Silero model at [modelPath].
  factory VvVad.open(
    String modelPath, {
    VvVadParams params = const VvVadParams(),
    String? hostPath,
  }) {
    final b = VvBindings(openVvNative(hostPath: hostPath));
    final (rc, address) = using((arena) {
      final p = arena<vv_vad_params>()..ref = b.vv_vad_default_params();
      p.ref
        ..threshold = params.threshold
        ..min_speech_ms = params.minSpeechMs
        ..min_silence_ms = params.minSilenceMs
        ..speech_pad_ms = params.speechPadMs
        ..max_speech_s = params.maxSpeechS
        ..n_threads = params.nThreads;
      final out = arena<Pointer<vv_vad>>();
      final rc = b.vv_vad_create(
        modelPath.toNativeUtf8(allocator: arena).cast(),
        p,
        out,
      );
      return (rc, out.value.address);
    });
    if (rc != VV_OK) throw VvVadException(rc, 'create');
    return VvVad._(b, Pointer<vv_vad>.fromAddress(address));
  }

  final VvBindings _b;
  Pointer<vv_vad> _h;

  bool get isDisposed => _h == nullptr;

  /// Speech segments of the concatenation of [ranges] (ms on that
  /// concatenated timeline). Resets the streaming state.
  List<VvSpeechSegment> segments(List<VvAudioRange> ranges) {
    _check();
    if (ranges.isEmpty) return const [];
    return using((arena) {
      final rs = arena<vv_audio_range>(ranges.length);
      for (var i = 0; i < ranges.length; i++) {
        rs[i].path = ranges[i].path.toNativeUtf8(allocator: arena).cast();
        rs[i].start_ms = ranges[i].startMs;
        rs[i].end_ms = ranges[i].endMs;
      }
      final out = arena<Pointer<Char>>();
      final rc = _b.vv_vad_segments(_h, rs, ranges.length, out);
      if (rc != VV_OK) throw VvVadException(rc, 'segments');
      final json = out.value.cast<Utf8>().toDartString();
      _b.vv_free_string(out.value);
      return [
        for (final m in (jsonDecode(json) as List).cast<Map<String, Object?>>())
          VvSpeechSegment(m['start_ms']! as int, m['end_ms']! as int),
      ];
    });
  }

  /// Streaming: feeds mono 16 kHz PCM16 samples.
  VvVadFeed feed(Int16List pcm) {
    _check();
    return using((arena) {
      final buf = arena<Int16>(pcm.isEmpty ? 1 : pcm.length);
      buf.asTypedList(pcm.length).setAll(0, pcm);
      final r = arena<vv_vad_feed_result>();
      final rc = _b.vv_vad_feed(_h, buf, pcm.length, r);
      if (rc != VV_OK) throw VvVadException(rc, 'feed');
      return VvVadFeed(r.ref.windows, r.ref.speech_windows, r.ref.max_prob);
    });
  }

  void reset() {
    _check();
    _b.vv_vad_reset(_h);
  }

  void dispose() {
    if (_h == nullptr) return;
    _b.vv_vad_destroy(_h);
    _h = nullptr;
  }

  void _check() {
    if (_h == nullptr) throw StateError('VvVad disposed');
  }
}

/// Streaming VAD on its own isolate (live recording, AUD-03): [feed] posts
/// PCM, [results] delivers one [VvVadFeed] per fed block, in order. The
/// UI isolate never runs the model.
class VvVadStream {
  VvVadStream._(this._send, this._results, this._exit);

  final SendPort _send;
  final StreamController<VvVadFeed> _results;
  final ReceivePort _exit;
  bool _closed = false;

  /// Loads the model on a new isolate. Throws [VvVadException] when it
  /// cannot be loaded.
  static Future<VvVadStream> spawn(
    String modelPath, {
    VvVadParams params = const VvVadParams(),
    String? hostPath,
  }) async {
    final ready = ReceivePort();
    final exit = ReceivePort();
    await Isolate.spawn(
      _main,
      (ready.sendPort, modelPath, params, hostPath),
      onExit: exit.sendPort,
      debugName: 'vv-vad-stream',
    );
    final results = StreamController<VvVadFeed>();
    final first = Completer<Object?>();
    ready.listen((msg) {
      if (!first.isCompleted) {
        first.complete(msg);
        return;
      }
      if (msg is (int, int, double)) {
        results.add(VvVadFeed(msg.$1, msg.$2, msg.$3));
      } else if (msg is int) {
        results.addError(VvVadException(msg, 'feed'));
      } else if (msg == null) {
        ready.close();
        unawaited(results.close());
      }
    });
    final hello = await first.future;
    if (hello is! SendPort) {
      ready.close();
      exit.close();
      throw VvVadException(hello is int ? hello : VV_E_INTERNAL, 'create');
    }
    return VvVadStream._(hello, results, exit);
  }

  Stream<VvVadFeed> get results => _results.stream;

  void feed(Int16List pcm) {
    if (_closed) return;
    _send.send(TransferableTypedData.fromList([pcm]));
  }

  /// Frees the model and ends [results].
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _send.send(null);
    await _results.done.timeout(const Duration(seconds: 5), onTimeout: () {});
    _exit.close();
  }

  static void _main((SendPort, String, VvVadParams, String?) args) {
    final (reply, modelPath, params, hostPath) = args;
    final VvVad vad;
    try {
      vad = VvVad.open(modelPath, params: params, hostPath: hostPath);
    } on VvVadException catch (e) {
      reply.send(e.code);
      return;
    } on Object {
      reply.send(VV_E_INTERNAL);
      return;
    }
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((msg) {
      if (msg is TransferableTypedData) {
        final pcm = msg.materialize().asInt16List();
        try {
          final r = vad.feed(pcm);
          reply.send((r.windows, r.speechWindows, r.maxProb));
        } on VvVadException catch (e) {
          reply.send(e.code);
        }
      } else if (msg == null) {
        vad.dispose();
        inbox.close();
        reply.send(null);
      }
    });
  }
}
