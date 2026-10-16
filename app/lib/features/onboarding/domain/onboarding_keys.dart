/// `settings` keys owned by onboarding (APP-01). Kept here (not in
/// `SettingKeys`) because they are not user-editable settings.
abstract final class OnboardingKeys {
  /// bool: the first-launch flow was finished (or skipped to the end).
  static const completed = 'onboarding.completed';

  /// int (UTC epoch ms): the user acknowledged the first-run recording
  /// consent explainer (SEC-07 first-run acknowledgement; required).
  static const consentAcknowledgedAt = 'consent.first_run_ack_at';

  /// bool: the microphone priming explanation was shown before the OS
  /// prompt (first Record tap).
  static const micPrimed = 'permissions.mic_primed';

  /// bool: the user explicitly chose to keep notes in the app's own folder
  /// instead of picking a vault folder (a skipped step is not a choice).
  static const notesInApp = 'onboarding.notes_in_app';
}

/// Onboarding pages in order. The microphone is only *explained* here — the
/// OS prompt comes on the first Record tap (never at launch).
enum OnboardingStep { privacy, consent, permissions, models, folder, ready }
