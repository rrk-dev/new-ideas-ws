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
  userPause('user_pause'),

  /// The microphone stream failed or the OS paused it by itself (AUD-01).
  captureError('capture_error');

  GapKind(this.wireName);

  /// Stored name of the gap marker.
  final String wireName;
}

/// Why a recording stopped.
enum StopCause {
  user,
  maxDuration,
  silence,

  /// Free space fell below the stop threshold (AUD-01 storage policy).
  lowStorage,
}

/// Something the capture reports on its own while a recording is open
/// (AUD-01). `RecordingController` reacts; nothing here ever resumes capture.
enum CaptureNotice {
  /// Free space is below the warning threshold.
  lowStorageWarning,

  /// Free space is below the stop threshold: stop and finalize now.
  lowStorageStop,

  /// The OS paused the microphone by itself (audio focus loss, interruption)
  /// — the recording must show as paused until the user taps Resume.
  interrupted,

  /// The microphone stream failed; capture is suspended.
  captureFailed,
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
  /// [cause] is persisted as the recording's stop reason.
  Future<Result<RecordedAudio>> close({StopCause cause = StopCause.user});

  /// Notices raised by the capture while a recording is open.
  Stream<CaptureNotice> get notices;
}
