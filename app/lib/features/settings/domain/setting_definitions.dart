import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Settings screen sections (APP-03), in display order.
enum SettingSection { audio, processing, export, privacy, license, about }

/// One persisted, user-editable setting: key, type, default and allowed
/// values. Labels live in the presentation layer (localised there).
sealed class SettingDef<T extends Object> {
  const SettingDef({
    required this.key,
    required this.section,
    required this.defaultValue,
  });

  /// `settings` table key (see [SettingKeys]).
  final String key;
  final SettingSection section;
  final T defaultValue;

  /// Decodes a stored JSON value; anything invalid falls back to
  /// [defaultValue] (a newer app version may have written it).
  T decode(Object? json);

  /// Whether [value] may be stored.
  bool accepts(Object? value);
}

/// On/off switch.
final class ToggleSetting extends SettingDef<bool> {
  const ToggleSetting({
    required super.key,
    required super.section,
    required super.defaultValue,
  });

  @override
  bool decode(Object? json) => json is bool ? json : defaultValue;

  @override
  bool accepts(Object? value) => value is bool;
}

/// One of a fixed set of option ids.
final class ChoiceSetting extends SettingDef<String> {
  const ChoiceSetting({
    required super.key,
    required super.section,
    required super.defaultValue,
    required this.options,
  });

  final List<String> options;

  @override
  String decode(Object? json) =>
      json is String && options.contains(json) ? json : defaultValue;

  @override
  bool accepts(Object? value) => value is String && options.contains(value);
}

/// Free text with a validator (e.g. the filename pattern).
final class TextSetting extends SettingDef<String> {
  const TextSetting({
    required super.key,
    required super.section,
    required super.defaultValue,
    required this.validate,
    this.maxLength = 200,
  });

  /// Returns an error code, or `null` when valid.
  final String? Function(String value) validate;
  final int maxLength;

  @override
  String decode(Object? json) =>
      json is String && validate(json) == null ? json : defaultValue;

  @override
  bool accepts(Object? value) => value is String && validate(value) == null;
}

/// Error codes of [validateFilenamePattern].
abstract final class PatternError {
  static const empty = 'empty';
  static const tooLong = 'too_long';
  static const unsafe = 'unsafe';
  static const unbalanced = 'unbalanced';
}

/// Filename pattern (EXP-02 token syntax): non-empty, ≤ 200 chars, no `..`
/// segments, no absolute path, balanced `{{ }}` tokens. Full rendering and
/// sanitising is EXP-02's; this only stops patterns that can never work.
String? validateFilenamePattern(String value) {
  final v = value.trim();
  if (v.isEmpty) return PatternError.empty;
  if (v.length > 200) return PatternError.tooLong;
  if (v.startsWith('/') ||
      v.contains(r'\') ||
      v.split('/').any((s) => s == '..' || s == '.')) {
    return PatternError.unsafe;
  }
  if ('{{'.allMatches(v).length != '}}'.allMatches(v).length) {
    return PatternError.unbalanced;
  }
  return null;
}

/// Option ids shared by retention settings (SEC-04 applies them).
abstract final class RetentionOption {
  static const forever = 'forever';
  static const afterExport = 'after_export';
  static const days7 = 'days_7';
  static const days30 = 'days_30';
  static const days90 = 'days_90';
}

/// Every setting the Settings screen edits, in display order. Defaults
/// marked PRODUCT-DECISION are engineering placeholders for the user to
/// confirm.
abstract final class AppSettings {
  static const inputDevice = ChoiceSetting(
    key: SettingKeys.audioInputDevice,
    section: SettingSection.audio,
    defaultValue: 'system',
    options: ['system', 'built_in', 'wired', 'bluetooth'],
  );
  static const agc = ToggleSetting(
    key: SettingKeys.audioAgc,
    section: SettingSection.audio,
    defaultValue: true,
  );
  static const noiseSuppression = ToggleSetting(
    key: SettingKeys.audioNoiseSuppression,
    section: SettingSection.audio,
    defaultValue: true,
  );
  static const autoPauseOnSilence = ToggleSetting(
    key: SettingKeys.audioAutoPause,
    section: SettingSection.audio,
    defaultValue: false,
  );

  /// PRODUCT-DECISION: default keeps audio until the user deletes it.
  static const audioRetention = ChoiceSetting(
    key: SettingKeys.audioRetention,
    section: SettingSection.audio,
    defaultValue: RetentionOption.forever,
    options: [
      RetentionOption.forever,
      RetentionOption.afterExport,
      RetentionOption.days30,
      RetentionOption.days7,
    ],
  );

  static const autoProcess = ToggleSetting(
    key: SettingKeys.processingAutoProcess,
    section: SettingSection.processing,
    defaultValue: true,
  );
  static const chargeOnly = ToggleSetting(
    key: SettingKeys.processingChargeOnly,
    section: SettingSection.processing,
    defaultValue: false,
  );

  /// PRODUCT-DECISION: speaker labels off unless a profile turns them on.
  static const diarizationDefault = ToggleSetting(
    key: SettingKeys.processingDiarization,
    section: SettingSection.processing,
    defaultValue: false,
  );

  /// Default per vv-markdown-vault-export (EXP-02).
  static const filenamePattern = TextSetting(
    key: SettingKeys.exportFilenamePattern,
    section: SettingSection.export,
    defaultValue: '{{date:YYYY-MM-DD}}-{{profile}}-{{slug}}.md',
    validate: validateFilenamePattern,
  );
  static const collisionMode = ChoiceSetting(
    key: SettingKeys.exportCollisionMode,
    section: SettingSection.export,
    defaultValue: 'suffix',
    options: ['suffix', 'overwrite', 'skip'],
  );

  static const appLock = ToggleSetting(
    key: SettingKeys.securityAppLock,
    section: SettingSection.privacy,
    defaultValue: false,
  );
  static const lockTimeout = ChoiceSetting(
    key: SettingKeys.securityLockTimeout,
    section: SettingSection.privacy,
    defaultValue: 'minutes_1',
    options: ['immediately', 'minutes_1', 'minutes_5', 'minutes_15'],
  );

  /// PRODUCT-DECISION: transcripts and extracted notes are kept by default.
  static const transcriptRetention = ChoiceSetting(
    key: SettingKeys.privacyTranscriptRetention,
    section: SettingSection.privacy,
    defaultValue: RetentionOption.forever,
    options: [
      RetentionOption.forever,
      RetentionOption.afterExport,
      RetentionOption.days90,
      RetentionOption.days30,
    ],
  );
  static const notificationsEnabled = ToggleSetting(
    key: SettingKeys.notificationsEnabled,
    section: SettingSection.privacy,
    defaultValue: true,
  );
  static const notificationDetails = ToggleSetting(
    key: SettingKeys.notificationsShowDetails,
    section: SettingSection.privacy,
    defaultValue: false,
  );

  static const List<SettingDef<Object>> all = [
    inputDevice,
    agc,
    noiseSuppression,
    autoPauseOnSilence,
    audioRetention,
    autoProcess,
    chargeOnly,
    diarizationDefault,
    filenamePattern,
    collisionMode,
    appLock,
    lockTimeout,
    transcriptRetention,
    notificationsEnabled,
    notificationDetails,
  ];

  static SettingDef<Object>? byKey(String key) {
    for (final d in all) {
      if (d.key == key) return d;
    }
    return null;
  }
}
