import 'package:vaultvoice/core/errors/result.dart';

/// A span of speech, in ms on the analysed file's timeline.
final class SpeechSpan {
  const SpeechSpan(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  @override
  String toString() => 'SpeechSpan($startMs, $endMs)';
}

/// Voice activity detection over audio files (AUD-03; whisper.cpp's Silero
/// VAD behind the native bridge). Runs in the pipeline worker isolate.
abstract interface class VadEngine {
  /// Speech spans of the 16 kHz mono WAV at [wavPath], using the ggml VAD
  /// model at [modelPath].
  Future<Result<List<SpeechSpan>>> speechSegments(
    String modelPath,
    String wavPath,
  );

  /// Frees the loaded model.
  Future<void> dispose();
}
