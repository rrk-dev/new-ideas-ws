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
    this.alsoDecodes,
  });

  final List<String> options;

  /// Extra values [decode] accepts although the user cannot pick them
  /// (e.g. a managed `days_N` retention, LIC-04). [accepts] stays strict.
  final bool Function(String value)? alsoDecodes;

  @override
  String decode(Object? json) =>
      json is String &&
          (options.contains(json) || alsoDecodes?.call(json) == true)
      ? json
      : defaultValue;

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

  /// `days_N` (N = 1..3650): the managed `audio_retention_days` value.
  static int? daysOf(String option) {
    final m = RegExp(r'^days_([1-9][0-9]{0,3})$').firstMatch(option);
    final n = m == null ? null : int.parse(m.group(1)!);
    return n != null && n <= 3650 ? n : null;
  }

  static bool isDays(String option) => daysOf(option) != null;
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

  /// AUD-02: provisional default off (platform AGC first); QA-02 decides.
  static const softwareAgc = ToggleSetting(
    key: SettingKeys.audioSoftwareAgc,
    section: SettingSection.audio,
    defaultValue: false,
  );
  static const rawCapture = ToggleSetting(
    key: SettingKeys.audioRawCapture,
    section: SettingSection.audio,
    defaultValue: false,
  );
  static const autoPauseOnSilence = ToggleSetting(
    key: SettingKeys.audioAutoPause,
    section: SettingSection.audio,
    defaultValue: false,
  );

  /// AUD-03. PRODUCT-DECISION: off by default (SEC-09 §6 asks for a
  /// configurable silence stop; the 4 h max-duration stop is always on).
  static const silenceAutoStop = ChoiceSetting(
    key: SettingKeys.audioSilenceAutoStop,
    section: SettingSection.audio,
    defaultValue: 'off',
    options: ['off', 'minutes_5', 'minutes_10', 'minutes_30'],
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
    alsoDecodes: RetentionOption.isDays,
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

  /// AUD-03: provisional default on — AC1 (≥ 20 % less STT time, ≤ 1 pt
  /// WER) is measured on the QA-02 corpus.
  static const skipSilence = ToggleSetting(
    key: SettingKeys.processingSkipSilence,
    section: SettingSection.processing,
    defaultValue: true,
  );

  /// MAP-02 / ADR-MAP-01. PRODUCT-DECISION: on demand by default (the step
  /// adds a model pass to every job; device cost is unmeasured). Values are
  /// `MindMapMode` names (`on_demand`, `auto`).
  static const mindMap = ChoiceSetting(
    key: SettingKeys.processingMindMap,
    section: SettingSection.processing,
    defaultValue: 'on_demand',
    options: ['on_demand', 'auto'],
  );

  /// ASK-04. PRODUCT-DECISION: off by default; the Ask entry stays hidden
  /// until the ASK-03 quality gates pass or the human decides otherwise.
  static const askEnabled = ToggleSetting(
    key: SettingKeys.askEnabled,
    section: SettingSection.processing,
    defaultValue: false,
  );

  /// ASK-03/ASK-04. PRODUCT-DECISION (human, 2026-10-17): chats are saved
  /// by default and expire after 30 days.
  static const askSaveHistory = ToggleSetting(
    key: SettingKeys.askSaveHistory,
    section: SettingSection.privacy,
    defaultValue: true,
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

  /// SEC-02 offline mode: no network at all (models must be installed or
  /// imported offline, MDL-04).
  static const offlineMode = ToggleSetting(
    key: SettingKeys.networkOffline,
    section: SettingSection.privacy,
    defaultValue: false,
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
    softwareAgc,
    rawCapture,
    autoPauseOnSilence,
    silenceAutoStop,
    audioRetention,
    autoProcess,
    chargeOnly,
    diarizationDefault,
    skipSilence,
    mindMap,
    askEnabled,
    filenamePattern,
    collisionMode,
    appLock,
    lockTimeout,
    transcriptRetention,
    askSaveHistory,
    offlineMode,
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
