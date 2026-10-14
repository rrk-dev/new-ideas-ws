import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_limits.dart';

/// A button on the OS recording indicator (Android ongoing notification,
/// AUD-05). Each is a user tap; Resume maps to
/// `ResumeSource.recordingNotification` (SEC-09 allowlist).
enum IndicatorAction {
  pause,
  resume,
  stop;

  static IndicatorAction? tryParse(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// What the OS indicator shows.
final class IndicatorContent {
  const IndicatorContent({
    required this.recording,
    required this.title,
    required this.text,
    required this.actions,
    this.chronometerBase,
  });

  /// True while capturing (paused otherwise).
  final bool recording;
  final String title;
  final String text;

  /// Wall-clock instant the on-screen chronometer counts from (recording
  /// only): `now − elapsed`.
  final DateTime? chronometerBase;
  final List<IndicatorAction> actions;
}

/// Indicator content for [state] (SEC-09 copy drafts, pending legal review).
/// Null when nothing should be shown (idle/stopped).
IndicatorContent? indicatorContentFor(RecordingState state, DateTime now) {
  switch (state.phase) {
    case RecordingPhase.idle || RecordingPhase.stopped:
      return null;
    case RecordingPhase.recording:
      return IndicatorContent(
        recording: true,
        title: 'Recording',
        text: 'VaultVoice is recording. Tap to open.',
        chronometerBase: now.subtract(state.elapsed),
        actions: const [IndicatorAction.pause, IndicatorAction.stop],
      );
    case RecordingPhase.paused:
      final (title, text) = switch (state.pauseCause) {
        PauseCause.call => (
          'Recording paused because a call started',
          'Audio from the call was not recorded. Tap Resume to continue.',
        ),
        PauseCause.audioInterruption ||
        PauseCause.captureSilenced ||
        PauseCause.captureError => (
          'Recording paused',
          'Another app or the system took the microphone. '
              'Tap Resume to continue.',
        ),
        _ => ('Recording paused', 'Tap Resume to continue.'),
      };
      return IndicatorContent(
        recording: false,
        title: title,
        text: text,
        actions: const [IndicatorAction.resume, IndicatorAction.stop],
      );
  }
}

/// The always-visible OS recording indicator (SEC-09 §6): Android ongoing
/// foreground-service notification of type `microphone` (AUD-05); iOS Live
/// Activity where supported (AUD-04). Also renders the "Still recording"
/// reminder.
abstract interface class RecordingIndicator implements RecordingReminderSink {
  /// Shows or updates the indicator. On Android the first call starts the
  /// microphone foreground service — only valid while the app is visible.
  Future<Result<void>> show(IndicatorContent content);

  /// Removes the indicator (stops the foreground service).
  Future<void> hide();

  /// Taps on the indicator's buttons.
  Stream<IndicatorAction> get actions;
}
