/// Long-session safeguards (SEC-09).
final class RecordingLimits {
  /// [maxDuration] is clamped to [1 min, [maxDurationCeiling]].
  RecordingLimits({
    Duration maxDuration = defaultMaxDuration,
    this.reminderInterval = const Duration(minutes: 60),
    this.silenceAutoStop,
  }) : maxDuration = _clamp(maxDuration);

  /// Default automatic stop (4 h).
  static const defaultMaxDuration = Duration(hours: 4);

  /// Highest user-configurable automatic stop (8 h).
  static const maxDurationCeiling = Duration(hours: 8);

  static const _floor = Duration(minutes: 1);

  /// Recording time (paused spans excluded) after which recording stops.
  final Duration maxDuration;

  /// "Still recording" reminder period while the app is backgrounded.
  final Duration reminderInterval;

  /// Stop after this much continuous silence (AUD-03 setting); null = off.
  final Duration? silenceAutoStop;

  static Duration _clamp(Duration d) {
    if (d > maxDurationCeiling) return maxDurationCeiling;
    if (d < _floor) return _floor;
    return d;
  }
}

/// Shows the "Still recording (1h 00m)" reminder. AUD-04/AUD-05 implement it
/// with the OS notification; tests use a recording fake.
abstract interface class RecordingReminderSink {
  void stillRecording(Duration elapsed);
}

/// Formats the reminder text, e.g. `Still recording (1h 00m)`.
String stillRecordingText(Duration elapsed) {
  final h = elapsed.inHours;
  final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  return 'Still recording (${h}h ${m}m)';
}
