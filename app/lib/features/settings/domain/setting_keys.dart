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

  /// bool, default `false`: the app's software AGC replaces the platform
  /// AGC (AUD-02; also the automatic fallback when the platform has none).
  static const audioSoftwareAgc = 'audio.software_agc';

  /// bool, default `false`: no platform or software processing (AUD-02).
  static const audioRawCapture = 'audio.raw_capture';
  static const audioAutoPause = 'audio.auto_pause_on_silence';

  /// `off` | `minutes_5` | `minutes_10` | `minutes_30`: stop a recording
  /// after this much continuous silence (AUD-03; needs the VAD model).
  static const audioSilenceAutoStop = 'audio.silence_auto_stop';

  /// Audio retention policy (SEC-04 applies it).
  static const audioRetention = 'audio.retention';

  // Processing (applied by the pipeline / FND-05 scheduling).
  static const processingAutoProcess = 'processing.auto_process';
  static const processingChargeOnly = 'processing.charge_only';
  static const processingDiarization = 'processing.diarization_default';

  /// bool, default `true`: skip silence before transcription with the VAD
  /// model when installed (AUD-03).
  static const processingSkipSilence = 'processing.skip_silence';

  // Export (EXP-02 / EXP-05).
  static const exportFilenamePattern = 'export.filename_pattern';
  static const exportCollisionMode = 'export.collision_mode';

  /// Map `{targetId: {collision, filename_pattern, transcript_sidecar,
  /// audio_sidecar}}` — per-target export options (EXP-05).
  static const exportTargetOptions = 'export.target_options';

  /// `{rules: bool, max_targets: int?}` — the routing entitlement mirrored
  /// from the UI isolate for the pipeline worker (EXP-05, LIC-01).
  static const exportRoutingPolicy = 'export.routing_policy';

  // Templates (EXP-07).
  /// `{templateId: {profile, base}}` — schema profile and built-in origin of
  /// each custom template (built-in profiles cannot be `templates.profile_id`).
  static const templatesMeta = 'templates.meta';

  /// `{profileId: templateId}` — custom template used for a profile's notes.
  static const templatesBindings = 'templates.bindings';

  // Privacy & security (SEC-03 / SEC-04).
  static const securityAppLock = 'security.app_lock';
  static const securityLockTimeout = 'security.lock_timeout';
  static const privacyTranscriptRetention = 'privacy.transcript_retention';
}
