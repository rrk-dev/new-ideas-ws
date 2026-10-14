import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// User-facing labels of settings, sections and options (from the ARB).
abstract final class SettingTexts {
  static String section(AppLocalizations l, SettingSection s) => switch (s) {
    SettingSection.audio => l.sectionAudio,
    SettingSection.processing => l.sectionProcessing,
    SettingSection.export => l.sectionExport,
    SettingSection.privacy => l.sectionPrivacy,
    SettingSection.license => l.sectionLicense,
    SettingSection.about => l.sectionAbout,
  };

  static String title(AppLocalizations l, String key) => switch (key) {
    SettingKeys.audioInputDevice => l.settingInputDevice,
    SettingKeys.audioAgc => l.settingAgc,
    SettingKeys.audioNoiseSuppression => l.settingNoiseSuppression,
    SettingKeys.audioAutoPause => l.settingAutoPause,
    SettingKeys.audioRetention => l.settingAudioRetention,
    SettingKeys.processingAutoProcess => l.settingAutoProcess,
    SettingKeys.processingChargeOnly => l.settingChargeOnly,
    SettingKeys.processingDiarization => l.settingDiarization,
    SettingKeys.exportFilenamePattern => l.settingFilenamePattern,
    SettingKeys.exportCollisionMode => l.settingCollisionMode,
    SettingKeys.securityAppLock => l.settingAppLock,
    SettingKeys.securityLockTimeout => l.settingLockTimeout,
    SettingKeys.privacyTranscriptRetention => l.settingTranscriptRetention,
    SettingKeys.notificationsEnabled => l.settingNotifications,
    SettingKeys.notificationsShowDetails => l.settingNotificationDetails,
    _ => key,
  };

  static String? description(AppLocalizations l, String key) => switch (key) {
    SettingKeys.audioAgc => l.settingAgcDescription,
    SettingKeys.audioAutoPause => l.settingAutoPauseDescription,
    SettingKeys.processingAutoProcess => l.settingAutoProcessDescription,
    SettingKeys.processingChargeOnly => l.settingChargeOnlyDescription,
    SettingKeys.processingDiarization => l.settingDiarizationDescription,
    SettingKeys.securityAppLock => l.settingAppLockDescription,
    SettingKeys.notificationsEnabled => l.settingNotificationsDescription,
    SettingKeys.notificationsShowDetails =>
      l.settingNotificationDetailsDescription,
    _ => null,
  };

  static String option(AppLocalizations l, String option) => switch (option) {
    'system' => l.optionSystemDefault,
    'built_in' => l.optionBuiltInMic,
    'wired' => l.optionWiredHeadset,
    'bluetooth' => l.optionBluetoothHeadset,
    RetentionOption.forever => l.optionKeepForever,
    RetentionOption.afterExport => l.optionDeleteAfterExport,
    RetentionOption.days7 => l.optionDays(7),
    RetentionOption.days30 => l.optionDays(30),
    RetentionOption.days90 => l.optionDays(90),
    'suffix' => l.optionCollisionSuffix,
    'overwrite' => l.optionCollisionOverwrite,
    'skip' => l.optionCollisionSkip,
    'immediately' => l.optionImmediately,
    'minutes_1' => l.optionMinutes(1),
    'minutes_5' => l.optionMinutes(5),
    'minutes_15' => l.optionMinutes(15),
    _ => option,
  };

  static String patternError(AppLocalizations l, String code) => switch (code) {
    PatternError.empty => l.patternErrorEmpty,
    PatternError.tooLong => l.patternErrorTooLong,
    PatternError.unsafe => l.patternErrorUnsafe,
    PatternError.unbalanced => l.patternErrorUnbalanced,
    _ => l.patternErrorInvalid,
  };
}
