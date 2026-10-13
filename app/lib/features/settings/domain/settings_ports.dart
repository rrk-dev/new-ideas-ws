import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Settings enforced by the organisation (LIC-04 managed configuration).
///
/// [values] override the user's choice (e.g. MDM `force_app_lock` →
/// `security.app_lock = true`); [locked] keys keep their current value but
/// cannot be changed (`lock_settings`). Both render read-only in Settings.
class ManagedSettings {
  const ManagedSettings({this.values = const {}, this.locked = const {}});

  static const none = ManagedSettings();

  final Map<String, Object?> values;
  final Set<String> locked;

  bool isManaged(String key) => values.containsKey(key) || locked.contains(key);
}

/// Source of [ManagedSettings]. LIC-04 implements it on top of the iOS
/// managed app configuration / Android app restrictions; until then
/// nothing is managed.
abstract interface class ManagedSettingsSource {
  Stream<ManagedSettings> watch();
}

class NoManagedSettings implements ManagedSettingsSource {
  const NoManagedSettings();

  @override
  Stream<ManagedSettings> watch() => Stream.value(ManagedSettings.none);
}

/// Licence tier as shown in Settings (only the licensing feature knows
/// plans; this is its display summary).
enum LicenseTier { free, pro, enterprise }

class LicenseSummary {
  const LicenseSummary({
    required this.tier,
    this.expiresAt,
    this.organization,
    this.inGracePeriod = false,
  });

  final LicenseTier tier;
  final DateTime? expiresAt;

  /// Licensee of an enterprise licence.
  final String? organization;

  /// Verification could not run; the offline grace period applies.
  final bool inGracePeriod;
}

/// What the Settings "License" section needs from licensing (LIC-01/02/03
/// adapt their services to this port). The default
/// [UnavailableLicensePort] reports Free and refuses actions.
abstract interface class LicenseSettingsPort {
  Stream<LicenseSummary> watch();

  /// Restores store purchases (StoreKit `AppStore.sync` / Play
  /// `queryPurchases`, LIC-02).
  Future<Result<void>> restorePurchases();

  /// Verifies and installs an enterprise licence (`*.vvlicense` content,
  /// LIC-03).
  Future<Result<void>> installEnterpriseLicense(String license);
}

class UnavailableLicensePort implements LicenseSettingsPort {
  const UnavailableLicensePort();

  @override
  Stream<LicenseSummary> watch() =>
      Stream.value(const LicenseSummary(tier: LicenseTier.free));

  @override
  Future<Result<void>> restorePurchases() async =>
      const Err(UnsupportedFeatureFailure('purchases'));

  @override
  Future<Result<void>> installEnterpriseLicense(String license) async =>
      const Err(UnsupportedFeatureFailure('enterprise licence'));
}

/// "Delete all data" (SEC-04 implements the secure wipe of DB, files, keys
/// and folder grants). The default refuses, so nothing pretends to delete.
abstract interface class DataWiper {
  Future<Result<void>> deleteAllData();
}

class UnavailableDataWiper implements DataWiper {
  const UnavailableDataWiper();

  @override
  Future<Result<void>> deleteAllData() async =>
      const Err(UnsupportedFeatureFailure('delete all data'));
}

/// Persistent key/value store of user settings (JSON values).
abstract interface class SettingsStore {
  Stream<Object?> watch(String key);

  Future<Result<void>> set(String key, Object? value);
}
