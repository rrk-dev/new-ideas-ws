/// App lock (SEC-03): pure decision logic, no Flutter / platform code.
library;

/// Result of a device authentication attempt.
enum AuthOutcome {
  /// Biometric or device passcode accepted.
  success,

  /// Cancelled or not recognised: stay locked, the user may retry.
  failed,

  /// The device has no passcode / biometrics (or the API is missing): the
  /// app cannot be locked. PRODUCT-DECISION: the lock is then not enforced
  /// (it would lock the user out of their own data) and Settings says so.
  unavailable,
}

/// Biometric / device-credential prompt (ADR-SEC-03).
abstract interface class DeviceAuthenticator {
  /// Shows the OS prompt with [reason]; device passcode fallback allowed.
  Future<AuthOutcome> authenticate(String reason);
}

/// Covers the app-switcher snapshot and blocks screenshots while the lock
/// is enabled (iOS overlay on scene deactivation; Android `FLAG_SECURE`).
abstract interface class PrivacyScreen {
  Future<void> setEnabled({required bool enabled});
}

/// `security.lock_timeout` option ids → time in background before the app
/// locks again. Unknown ids lock immediately (fail safe).
Duration lockTimeoutFor(String option) => switch (option) {
  'minutes_1' => const Duration(minutes: 1),
  'minutes_5' => const Duration(minutes: 5),
  'minutes_15' => const Duration(minutes: 15),
  _ => Duration.zero,
};

/// The lock state machine: locked on launch, re-locked after [timeout] in
/// the background, unlocked only by a successful authentication.
class AppLockMachine {
  AppLockMachine({required bool enabled, required this.timeout})
    : _enabled = enabled,
      _locked = enabled;

  bool _enabled;
  bool _locked;
  DateTime? _backgroundedAt;

  /// Time in background before locking again.
  Duration timeout;

  bool get enabled => _enabled;

  /// Content must be hidden.
  bool get locked => _enabled && _locked;

  /// Settings changed. Turning the lock on does not lock the running
  /// session (the user just authenticated by changing the setting); turning
  /// it off unlocks.
  set enabled(bool value) {
    if (!value) _locked = false;
    _enabled = value;
  }

  /// The app went to the background (`paused` / `hidden`).
  void backgrounded(DateTime now) => _backgroundedAt ??= now;

  /// The app is visible again.
  void resumed(DateTime now) {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (_enabled && since != null && now.difference(since) >= timeout) {
      _locked = true;
    }
  }

  /// Applies an authentication result. [AuthOutcome.unavailable] unlocks:
  /// without device credentials there is nothing to authenticate against.
  void authenticated(AuthOutcome outcome) {
    if (outcome != AuthOutcome.failed) _locked = false;
  }
}
