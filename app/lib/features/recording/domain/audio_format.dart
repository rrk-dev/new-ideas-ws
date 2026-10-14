/// The audio format contract every downstream step relies on
/// (`vv-audio-capture` → Format contract): PCM 16-bit little-endian,
/// 16 000 Hz, mono, in rolling chunks of [defaultChunkDuration].
abstract final class AudioFormat {
  /// Target sample rate (whisper.cpp input).
  static const sampleRate = 16000;

  /// Mono.
  static const channels = 1;

  /// PCM16.
  static const bytesPerSample = 2;

  /// Bytes per second of the target format (32 000).
  static const int bytesPerSecond = sampleRate * channels * bytesPerSample;

  /// Default length of one chunk file.
  static const defaultChunkDuration = Duration(minutes: 5);

  /// Number of samples (per channel) in [d] at [sampleRate], rounded down.
  static int samplesFor(Duration d) => d.inMicroseconds * sampleRate ~/ 1000000;

  /// Duration of [samples] at [sampleRate] (exact to the microsecond).
  static Duration durationOf(int samples) =>
      Duration(microseconds: samples * 1000000 ~/ sampleRate);

  /// Milliseconds of [samples] at [sampleRate] (rounded down).
  static int msOf(int samples) => samples * 1000 ~/ sampleRate;
}

/// Kind of an input route, mapped from the platform's device type.
enum AudioInputKind {
  builtIn,
  wired,

  /// Bluetooth hands-free (HFP/SCO): 8 or 16 kHz on the air, resampled.
  bluetooth,
  usb,
  unknown,
}

/// A selectable microphone input (`listInputDevices`).
final class AudioInputDevice {
  const AudioInputDevice({
    required this.id,
    required this.label,
    this.kind = AudioInputKind.unknown,
  });

  /// Platform id used to select the device.
  final String id;

  /// Human-readable name (device names may identify the user's hardware:
  /// never log it at INFO or above).
  final String label;

  final AudioInputKind kind;
}
