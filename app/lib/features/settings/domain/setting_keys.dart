/// Keys of the `settings` table (FND-04 key/value store, JSON values).
///
/// Every key is listed here once so features and the Settings screen agree
/// on names; renaming a key is a data migration.
abstract final class SettingKeys {
  /// bool, default `true`: post local notifications when a note is ready or
  /// processing failed (APP-04).
  static const notificationsEnabled = 'notifications.enabled';

  /// bool, default `false`: include the recording title in notifications.
  /// Off = generic text ("Your note is ready"), safe on the lock screen.
  static const notificationsShowDetails = 'notifications.show_details';

  /// bool: the OS notification permission prompt was shown once.
  static const notificationsPermissionAsked = 'notifications.permission_asked';

  // Audio (APP-03; applied by AUD-xx).
  static const audioInputDevice = 'audio.input_device';
  static const audioAgc = 'audio.agc';
  static const audioNoiseSuppression = 'audio.noise_suppression';
  static const audioAutoPause = 'audio.auto_pause_on_silence';

  /// Audio retention policy (SEC-04 applies it).
  static const audioRetention = 'audio.retention';

  // Processing (applied by the pipeline / FND-05 scheduling).
  static const processingAutoProcess = 'processing.auto_process';
  static const processingChargeOnly = 'processing.charge_only';
  static const processingDiarization = 'processing.diarization_default';

  // Export (EXP-02 / EXP-05).
  static const exportFilenamePattern = 'export.filename_pattern';
  static const exportCollisionMode = 'export.collision_mode';

  // Privacy & security (SEC-03 / SEC-04).
  static const securityAppLock = 'security.app_lock';
  static const securityLockTimeout = 'security.lock_timeout';
  static const privacyTranscriptRetention = 'privacy.transcript_retention';
}
