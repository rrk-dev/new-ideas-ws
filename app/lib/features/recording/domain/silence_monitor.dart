/// What the live VAD asks the recording to do (AUD-03). There is
/// deliberately no "start" or "resume" action: VAD may only pause or stop a
/// recording (SEC-09 §4 — no voice-activated recording).
enum SilenceAction { pause, stop }

/// Silence settings of one recording.
final class SilencePolicy {
  const SilencePolicy({this.autoPauseAfter, this.autoStopAfter});

  /// From the stored setting values.
  factory SilencePolicy.fromSettings({
    required bool autoPause,
    required String autoStop,
  }) => SilencePolicy(
    autoPauseAfter: autoPause ? defaultAutoPause : null,
    autoStopAfter: switch (autoStop) {
      'minutes_5' => const Duration(minutes: 5),
      'minutes_10' => const Duration(minutes: 10),
      'minutes_30' => const Duration(minutes: 30),
      _ => null,
    },
  );

  static const off = SilencePolicy();

  /// Default auto-pause delay when `audio.auto_pause_on_silence` is on.
  // PRODUCT-DECISION: 2 minutes (short pauses in a meeting must not pause).
  static const defaultAutoPause = Duration(minutes: 2);

  /// `audio.auto_pause_on_silence`; null = off.
  final Duration? autoPauseAfter;

  /// `audio.silence_auto_stop`; null = off.
  final Duration? autoStopAfter;

  bool get enabled => autoPauseAfter != null || autoStopAfter != null;
}

/// Counts continuous silence from live VAD results and decides when to
/// auto-pause / auto-stop (pure logic; `SilenceWatcher` feeds it).
///
/// * A window counts as speech when the VAD said so; any speech resets the
///   silence counter.
/// * Each action fires at most once per silence stretch; stop wins when both
///   thresholds are crossed by the same block.
/// * [restart] after a (user) resume: silence counts from zero again.
class SilenceMonitor {
  SilenceMonitor(this.policy);

  final SilencePolicy policy;

  /// Silence window length of the VAD (Silero: 512 samples at 16 kHz).
  static const window = Duration(milliseconds: 32);

  Duration _silence = Duration.zero;
  bool _paused = false;
  bool _stopped = false;

  /// Current continuous silence.
  Duration get silence => _silence;

  /// Feeds one VAD result ([windows] analysed, [speechWindows] of them
  /// speech). Returns the action to take now, if any.
  SilenceAction? add(int windows, int speechWindows) {
    if (_stopped || windows <= 0) return null;
    if (speechWindows > 0) {
      _silence = Duration.zero;
      _paused = false;
      return null;
    }
    _silence += window * windows;
    final stopAt = policy.autoStopAfter;
    if (stopAt != null && _silence >= stopAt) {
      _stopped = true;
      return SilenceAction.stop;
    }
    final pauseAt = policy.autoPauseAfter;
    if (pauseAt != null && !_paused && _silence >= pauseAt) {
      _paused = true;
      return SilenceAction.pause;
    }
    return null;
  }

  /// The user resumed: count silence from zero again.
  void restart() {
    _silence = Duration.zero;
    _paused = false;
  }
}
