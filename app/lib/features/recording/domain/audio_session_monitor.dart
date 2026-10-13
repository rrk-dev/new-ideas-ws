/// What the platform audio session reported (iOS AVAudioSession /
/// AVAudioEngine, AUD-04).
enum AudioSessionEventKind {
  /// `AVAudioSession.routeChangeNotification` (AirPods / wired headset
  /// connected or removed …). Recording continues; logged only.
  routeChanged,

  /// `AVAudioEngineConfigurationChange`: the engine stopped because the I/O
  /// format changed (typically with a route change) — the input must be
  /// reopened.
  engineConfigurationChanged,

  /// `AVAudioSession.mediaServicesWereResetNotification`: every audio object
  /// is invalid — rebuild the engine and continue in a new chunk.
  mediaServicesReset;

  static AudioSessionEventKind? tryParse(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// One audio-session observation.
final class AudioSessionEvent {
  const AudioSessionEvent(this.kind, {this.reason, this.inputs = const []});

  final AudioSessionEventKind kind;

  /// Route-change reason (`newDeviceAvailable`, `oldDeviceUnavailable`, …).
  final String? reason;

  /// Port types of the current input route (e.g. `MicrophoneBuiltIn`,
  /// `BluetoothHFP`) — device kinds only, never device names.
  final List<String> inputs;
}

/// Observes the platform audio session while a recording is open.
abstract interface class AudioSessionMonitor {
  Stream<AudioSessionEvent> get events;
}

/// Platforms whose capture handles routing itself (Android `AudioRecord`).
final class NoAudioSessionMonitor implements AudioSessionMonitor {
  const NoAudioSessionMonitor();

  @override
  Stream<AudioSessionEvent> get events => const Stream.empty();
}
