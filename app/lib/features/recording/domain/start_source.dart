/// Where a recording start request came from (SEC-09).
///
/// Every value is a **deliberate user tap**. There is intentionally no value
/// for scheduled/automated starts (Shortcuts automations, alarms, timers,
/// geofences), voice activation, push/MDM/remote triggers, app launch or any
/// background/headless context: such callers cannot even express a start.
/// Adding a value requires amending ADR-SEC-09 (a test pins this set).
enum StartSource {
  /// The Record button on the in-app recording screen.
  inAppButton,

  /// A tap on the app's home-screen widget (opens the app first).
  homeScreenWidget,

  /// A tap on the Android quick-settings tile (opens the app first).
  androidQuickSettingsTile,

  /// A tap on the iOS Control (App Intent with `openAppWhenRun`; AUD-08).
  iosControl,
}

/// Where a resume request came from. Resume after a pause — including the
/// pause forced by a call — always needs a user tap; nothing resumes
/// automatically.
enum ResumeSource {
  /// The Resume button on the in-app recording screen.
  inAppButton,

  /// The Resume action of the ongoing recording notification (AUD-05).
  recordingNotification,
}

/// The policy allowlist the controller checks against (defence in depth: a
/// new enum value is refused until it is added here and to the ADR).
const allowedStartSources = <StartSource>{
  StartSource.inAppButton,
  StartSource.homeScreenWidget,
  StartSource.androidQuickSettingsTile,
  StartSource.iosControl,
};

/// Allowlist for [ResumeSource]s.
const allowedResumeSources = <ResumeSource>{
  ResumeSource.inAppButton,
  ResumeSource.recordingNotification,
};
