import 'dart:typed_data';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// Android audio source. **Only** these two are allowed (SEC-09,
/// ADR-SEC-09 §1); there is deliberately no way to express another.
enum MicAudioSource {
  /// `MediaRecorder.AudioSource.VOICE_RECOGNITION`: tuned for speech
  /// recognition (no AGC on most devices). Default.
  voiceRecognition,

  /// `MediaRecorder.AudioSource.MIC`.
  mic,
}

/// What the capture asks the platform for.
final class MicRequest {
  const MicRequest({
    this.device,
    this.androidSource = MicAudioSource.voiceRecognition,
    this.autoGain = false,
    this.echoCancel = false,
    this.noiseSuppress = false,
  });

  /// Null = the platform default input.
  final AudioInputDevice? device;
  final MicAudioSource androidSource;

  /// Platform voice-processing flags. Off by default: AUD-02 decides from
  /// QA-02 corpus data (voice processing can hurt far-field audio).
  final bool autoGain;
  final bool echoCancel;
  final bool noiseSuppress;
}

/// The format the platform actually delivers (may differ from 16 kHz mono,
/// e.g. Bluetooth HFP or fixed-rate HALs).
final class MicFormat {
  const MicFormat({required this.sampleRate, required this.channels});

  static const contract = MicFormat(
    sampleRate: AudioFormat.sampleRate,
    channels: AudioFormat.channels,
  );

  final int sampleRate;
  final int channels;
}

/// Events from an open microphone stream.
sealed class MicEvent {
  const MicEvent();
}

/// PCM16 LE bytes in the current [MicFormat], with the time they arrived.
final class MicData extends MicEvent {
  const MicData(this.bytes, this.receivedAt);

  final Uint8List bytes;
  final DateTime receivedAt;
}

/// The platform adjusted the format (reported before/with the first data).
final class MicFormatChanged extends MicEvent {
  const MicFormatChanged(this.format);

  final MicFormat format;
}

/// The platform paused capture by itself (audio focus loss, OS
/// interruption). Never resumed automatically.
final class MicInterrupted extends MicEvent {
  const MicInterrupted();
}

/// The stream failed or ended unexpectedly.
final class MicFailed extends MicEvent {
  const MicFailed(this.errorType);

  /// `runtimeType` of the error (never its message).
  final String errorType;
}

/// The standard OS microphone API (iOS AVAudioSession/AVAudioEngine,
/// Android `AudioRecord`) behind a seam so capture logic is testable.
/// Implemented with the `record` package (`RecordMicSource`).
///
/// Only `RecordCaptureBackend` calls [open], and only from
/// `CaptureBackend.openMicrophone/resumeCapture` (SEC-09).
abstract interface class PcmMicSource {
  /// Whether microphone permission is granted; requests it when
  /// [request] (only ever after the user's Record tap).
  Future<bool> hasPermission({bool request = true});

  /// Available inputs.
  Future<Result<List<AudioInputDevice>>> inputDevices();

  /// Opens the microphone and streams [MicEvent]s until [close].
  Future<Result<Stream<MicEvent>>> open(MicRequest request);

  /// Stops capture (releases the microphone). Idempotent.
  Future<void> close();
}
