import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// Keys of the MDM managed configuration (LIC-04). Documented for admins in
/// `docs/mdm-config.md`; the names are the wire contract (iOS/macOS managed
/// app configuration dictionary, Android `app_restrictions.xml`).
abstract final class ManagedKeys {
  static const String license = 'license';
  static const profilePacks = 'profile_packs';
  static const allowedTargetKinds = 'allowed_target_kinds';
  static const audioRetentionDays = 'audio_retention_days';
  static const networkDisabled = 'network_disabled';
  static const lockSettings = 'lock_settings';
  static const forceAppLock = 'force_app_lock';
  static const disableCustomModels = 'disable_custom_models';
  static const forceConsentConfirmation = 'force_consent_confirmation';
  static const maxRecordingMinutes = 'max_recording_minutes';

  static const Set<String> all = {
    license,
    profilePacks,
    allowedTargetKinds,
    audioRetentionDays,
    networkDisabled,
    lockSettings,
    forceAppLock,
    disableCustomModels,
    forceConsentConfirmation,
    maxRecordingMinutes,
  };
}

/// Vault target kinds an admin can allow (`allowed_target_kinds` values;
/// they match `VaultTargetKind` names in snake case).
abstract final class ManagedTargetKinds {
  static const saf = 'saf';
  static const bookmark = 'bookmark';
  static const appLocal = 'app_local';

  static const Set<String> all = {saf, bookmark, appLocal};
}

/// Size caps: a managed value is untrusted input like any other.
abstract final class ManagedLimits {
  static const maxLicenseChars = 131072;
  static const maxPacks = 20;
  static const int maxPackChars = 3 * 1024 * 1024;
  static const maxListEntries = 64;
  static const maxRetentionDays = 3650;
  static const maxRecordingMinutes = 480;
}

/// The validated managed configuration.
///
/// Parsing never throws: an unknown key, a value of the wrong type or out of
/// range is dropped and its *key name* (never the value) recorded in
/// [ignoredKeys]. Every key can only tighten the app (SEC-09): there is no
/// key that starts a recording, hides an indicator, or disables the call
/// guard or a consent step, and a missing or invalid value never loosens a
/// default. Encryption at rest is always on and has no key.
final class ManagedConfig {
  const ManagedConfig({
    this.license,
    this.profilePacks = const [],
    this.allowedTargetKinds,
    this.audioRetentionDays,
    this.networkDisabled = false,
    this.lockSettings = const {},
    this.forceAppLock = false,
    this.disableCustomModels = false,
    this.forceConsentConfirmation = false,
    this.maxRecordingMinutes,
    this.ignoredKeys = const {},
  });

  /// Parses the platform dictionary; see the class comment.
  factory ManagedConfig.parse(Map<String, Object?> raw) {
    final ignored = <String>{
      for (final k in raw.keys)
        if (!ManagedKeys.all.contains(k)) k,
    };

    T? take<T>(String key, T? Function(Object value) convert) {
      final v = raw[key];
      if (v == null) return null;
      final out = convert(v);
      if (out == null) ignored.add(key);
      return out;
    }

    bool flag(String key) => take<bool>(key, _asBool) ?? false;

    final license = take<String>(ManagedKeys.license, (v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty || t.length > ManagedLimits.maxLicenseChars ? null : t;
    });

    final packs = take<List<String>>(ManagedKeys.profilePacks, (v) {
      final items = _asList(v);
      if (items == null || items.length > ManagedLimits.maxPacks) return null;
      final out = <String>[];
      for (final item in items) {
        final s = item is Map ? item['pack'] : item;
        if (s is! String) return null;
        final t = s.trim();
        if (t.isEmpty || t.length > ManagedLimits.maxPackChars) return null;
        // A link is never followed (no network additions, LIC-04).
        if (_looksLikeUrl(t)) return null;
        out.add(t);
      }
      return out;
    });

    final kinds = take<Set<String>>(ManagedKeys.allowedTargetKinds, (v) {
      final items = _asList(v);
      if (items == null || items.length > ManagedLimits.maxListEntries) {
        return null;
      }
      return {
        for (final i in items)
          if (i is String && ManagedTargetKinds.all.contains(i.trim()))
            i.trim(),
        ManagedTargetKinds.appLocal,
      };
    });

    final lock = take<Set<String>>(ManagedKeys.lockSettings, (v) {
      final items = _asList(v);
      if (items == null || items.length > ManagedLimits.maxListEntries) {
        return null;
      }
      return {
        for (final i in items)
          if (i is String && AppSettings.byKey(i.trim()) != null) i.trim(),
      };
    });

    return ManagedConfig(
      license: license,
      profilePacks: packs ?? const [],
      allowedTargetKinds: kinds,
      audioRetentionDays: take<int>(
        ManagedKeys.audioRetentionDays,
        (v) => _asInt(v, 1, ManagedLimits.maxRetentionDays),
      ),
      networkDisabled: flag(ManagedKeys.networkDisabled),
      lockSettings: lock ?? const {},
      forceAppLock: flag(ManagedKeys.forceAppLock),
      disableCustomModels: flag(ManagedKeys.disableCustomModels),
      forceConsentConfirmation: flag(ManagedKeys.forceConsentConfirmation),
      maxRecordingMinutes: take<int>(
        ManagedKeys.maxRecordingMinutes,
        (v) => _asInt(v, 1, ManagedLimits.maxRecordingMinutes),
      ),
      ignoredKeys: ignored,
    );
  }

  static const none = ManagedConfig();

  /// `.vvlicense` file content or its base64 (verified by LIC-03).
  final String? license;

  /// Base64 `.vvprofile` bundles. Never a URL: nothing is fetched.
  final List<String> profilePacks;

  /// Vault target kinds notes may use; null = no restriction. The app's own
  /// folder is always included so an export always has a destination.
  final Set<String>? allowedTargetKinds;

  final int? audioRetentionDays;
  final bool networkDisabled;

  /// Known setting keys the user cannot change.
  final Set<String> lockSettings;

  final bool forceAppLock;
  final bool disableCustomModels;
  final bool forceConsentConfirmation;

  /// Automatic recording stop in minutes. The recorder applies the smaller
  /// of this and its own limit, so it can never extend a recording.
  final int? maxRecordingMinutes;

  /// Keys present but not applied (key names only).
  final Set<String> ignoredKeys;

  bool get isEmpty =>
      license == null &&
      profilePacks.isEmpty &&
      allowedTargetKinds == null &&
      audioRetentionDays == null &&
      !networkDisabled &&
      lockSettings.isEmpty &&
      !forceAppLock &&
      !disableCustomModels &&
      !forceConsentConfirmation &&
      maxRecordingMinutes == null;

  bool allowsTargetKind(String kind) =>
      allowedTargetKinds == null || allowedTargetKinds!.contains(kind);

  /// The settings this configuration forces or locks (Settings renders them
  /// read-only, APP-03).
  ManagedSettings toManagedSettings() => ManagedSettings(
    values: {
      if (forceAppLock) SettingKeys.securityAppLock: true,
      if (networkDisabled) SettingKeys.networkOffline: true,
      if (audioRetentionDays != null)
        SettingKeys.audioRetention: 'days_$audioRetentionDays',
    },
    locked: lockSettings,
  );

  static bool? _asBool(Object v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return null;
  }

  static int? _asInt(Object v, int min, int max) {
    final n = switch (v) {
      int() => v,
      double() when v == v.truncateToDouble() => v.toInt(),
      String() => int.tryParse(v.trim()),
      _ => null,
    };
    return n == null || n < min || n > max ? null : n;
  }

  static List<Object?>? _asList(Object v) => switch (v) {
    List<Object?>() => v,
    String() => [v],
    _ => null,
  };

  static bool _looksLikeUrl(String s) {
    final head = s.length > 12 ? s.substring(0, 12) : s;
    return RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(head);
  }
}
