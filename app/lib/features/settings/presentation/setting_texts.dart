import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// User-facing labels of settings, sections and options (English; APP-06
/// moves them to ARB).
abstract final class SettingTexts {
  static String section(SettingSection s) => switch (s) {
    SettingSection.audio => 'Audio',
    SettingSection.processing => 'Processing',
    SettingSection.export => 'Export',
    SettingSection.privacy => 'Privacy & security',
    SettingSection.license => 'License',
    SettingSection.about => 'About',
  };

  static String title(String key) => switch (key) {
    SettingKeys.audioInputDevice => 'Input device',
    SettingKeys.audioAgc => 'Automatic gain control',
    SettingKeys.audioNoiseSuppression => 'Noise suppression',
    SettingKeys.audioAutoPause => 'Auto-pause on silence',
    SettingKeys.audioRetention => 'Keep audio',
    SettingKeys.processingAutoProcess => 'Process after recording',
    SettingKeys.processingChargeOnly => 'Process only while charging',
    SettingKeys.processingDiarization => 'Label speakers by default',
    SettingKeys.exportFilenamePattern => 'File name pattern',
    SettingKeys.exportCollisionMode => 'If the file already exists',
    SettingKeys.securityAppLock => 'App lock',
    SettingKeys.securityLockTimeout => 'Lock after',
    SettingKeys.privacyTranscriptRetention => 'Keep transcripts and notes',
    SettingKeys.notificationsEnabled => 'Notifications',
    SettingKeys.notificationsShowDetails => 'Show details in notifications',
    _ => key,
  };

  static String? description(String key) => switch (key) {
    SettingKeys.audioAgc => 'Evens out quiet and loud voices.',
    SettingKeys.audioAutoPause => 'Pauses capture during long silences.',
    SettingKeys.processingAutoProcess =>
      'Transcribe and extract as soon as a recording ends.',
    SettingKeys.processingChargeOnly =>
      'Wait for a charger before heavy processing.',
    SettingKeys.processingDiarization =>
      'Profiles can still turn speaker labels on or off.',
    SettingKeys.securityAppLock => 'Face ID, fingerprint or device passcode.',
    SettingKeys.notificationsEnabled =>
      'When a note is ready or processing needs attention.',
    SettingKeys.notificationsShowDetails =>
      'Include the recording title. Off: generic text on the lock screen.',
    _ => null,
  };

  static String option(String key, String option) => switch (option) {
    'system' => 'System default',
    'built_in' => 'Built-in microphone',
    'wired' => 'Wired headset',
    'bluetooth' => 'Bluetooth headset',
    RetentionOption.forever => 'Until I delete it',
    RetentionOption.afterExport => 'Delete after export',
    RetentionOption.days7 => '7 days',
    RetentionOption.days30 => '30 days',
    RetentionOption.days90 => '90 days',
    'suffix' => 'Add a number (-2, -3 …)',
    'overwrite' => 'Replace my earlier export',
    'skip' => 'Skip',
    'immediately' => 'Immediately',
    'minutes_1' => '1 minute',
    'minutes_5' => '5 minutes',
    'minutes_15' => '15 minutes',
    _ => option,
  };

  static String patternError(String code) => switch (code) {
    PatternError.empty => 'Enter a pattern.',
    PatternError.tooLong => 'Use at most 200 characters.',
    PatternError.unsafe => 'Folders must stay inside the vault.',
    PatternError.unbalanced => 'Every {{ needs a matching }}.',
    _ => 'Invalid pattern.',
  };

  static const managed = 'Managed by your organization';
}
