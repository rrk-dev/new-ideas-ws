import 'package:vaultvoice/core/errors/result.dart';

/// A finished recording on disk.
class RecordedAudio {
  const RecordedAudio({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

/// Microphone capture.
///
/// Recording policy (SEC-09): [start] may only be called as the direct result
/// of an explicit user tap, and implementations must stop when a call starts.
abstract interface class AudioRecorder {
  bool get isRecording;

  /// Input level in 0.0–1.0 while recording.
  Stream<double> get levels;

  Future<Result<void>> start();

  Future<Result<RecordedAudio>> stop();
}
