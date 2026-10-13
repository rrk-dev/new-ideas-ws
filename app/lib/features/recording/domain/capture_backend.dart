import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';

/// Gap marker kinds written into the recording when capture is suspended
/// (`vv-audio-capture` → format contract: time base excludes gaps).
enum GapKind {
  /// A phone/VoIP call rang or started (`call_interruption`).
  callInterruption('call_interruption'),

  /// The OS interrupted the audio session (alarm, Siri, other app).
  audioInterruption('audio_interruption'),

  /// The OS silenced our capture.
  captureSilenced('capture_silenced'),

  /// The user tapped Pause.
  userPause('user_pause');

  GapKind(this.wireName);

  /// Stored name of the gap marker.
  final String wireName;
}

/// The microphone capture that `RecordingController` drives.
///
/// SEC-09 provides only this seam; AUD-01 implements it with the `record`
/// package (iOS AVAudioSession/AVAudioEngine, Android `AudioRecord` with the
/// MIC or VOICE_RECOGNITION source only) and writes the 16 kHz WAV chunks.
/// Only `RecordingController` may call these methods.
abstract interface class CaptureBackend {
  /// Opens the microphone input and starts capturing. Called only after the
  /// user's tap passed every policy check — never earlier (no pre-capture).
  Future<Result<void>> openMicrophone();

  /// Stops capture **now**, drops every sample captured at or after
  /// [discardFrom] (the call-start time; null = keep everything captured so
  /// far), finalizes the current chunk and writes a [gap] marker.
  Future<Result<void>> suspend({required GapKind gap, DateTime? discardFrom});

  /// Reopens the microphone after [suspend]. Called only on a user tap.
  Future<Result<void>> resumeCapture();

  /// Stops capture, finalizes the last chunk and returns the recording.
  Future<Result<RecordedAudio>> close();
}
