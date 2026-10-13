import 'package:vaultvoice/core/errors/result.dart';

/// What the platform call guard observed (SEC-09, ADR-SEC-09).
///
/// iOS: `CXCallObserver` (any call with `hasEnded == false`) and
/// `AVAudioSession` interruptions. Android: `AudioManager` mode (ringtone,
/// in-call, in-communication, call screening/redirect) and
/// `AudioRecordingCallback.isClientSilenced` (API 29+). No phone-state
/// permission is used on either platform.
enum CallGuardSignal {
  /// A cellular or VoIP call is ringing or active.
  callActive,

  /// No call is ringing or active any more. Never resumes capture by itself.
  callEnded,

  /// The OS interrupted the audio session (treated like a call).
  interruptionBegan,

  /// The audio-session interruption ended. Never resumes capture by itself.
  interruptionEnded,

  /// The OS silenced our capture (e.g. a call took the microphone).
  captureSilenced,

  /// Our capture is no longer silenced. Never resumes capture by itself.
  captureUnsilenced;

  /// Whether capture must stop immediately when this signal arrives.
  bool get blocksCapture => switch (this) {
    callActive || interruptionBegan || captureSilenced => true,
    callEnded || interruptionEnded || captureUnsilenced => false,
  };

  /// Parses the wire name sent by the platform side; null when unknown.
  static CallGuardSignal? tryParse(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// One call-guard observation with the platform time it happened at. Audio
/// captured at or after [at] must be discarded when [signal] blocks capture.
final class CallGuardEvent {
  const CallGuardEvent(this.signal, this.at);

  final CallGuardSignal signal;
  final DateTime at;

  @override
  String toString() => 'CallGuardEvent(${signal.name}, $at)';
}

/// Detects phone/VoIP calls without any call-related permission (SEC-09).
abstract interface class CallGuard {
  /// Whether a call is ringing or active right now. An [Err] means the state
  /// is unknown; callers must then fail closed (refuse to record).
  Future<Result<bool>> isInCall();

  /// Call/interruption observations while subscribed. Platform observers run
  /// only while there is a listener.
  Stream<CallGuardEvent> get events;
}
