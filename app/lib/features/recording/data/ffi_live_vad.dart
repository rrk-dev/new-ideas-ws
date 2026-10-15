import 'dart:async';
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/data/silence_watcher.dart';
import 'package:vv_native/vv_native.dart';

/// [LiveVad] on `VvVadStream`: the Silero model runs on its own isolate,
/// the UI isolate only posts PCM (AUD-03).
class FfiLiveVad implements LiveVad {
  FfiLiveVad._(this._stream);

  final VvVadStream _stream;

  /// Loads the model at [modelPath]; null when it cannot be loaded.
  static Future<FfiLiveVad?> open(String modelPath, {String? hostPath}) async {
    try {
      return FfiLiveVad._(
        await VvVadStream.spawn(modelPath, hostPath: hostPath),
      );
    } on Object {
      return null;
    }
  }

  @override
  void feed(Int16List pcm) => _stream.feed(pcm);

  @override
  Stream<VadCounts> get results =>
      _stream.results.map((r) => (windows: r.windows, speech: r.speechWindows));

  @override
  Future<void> close() => _stream.close();
}
