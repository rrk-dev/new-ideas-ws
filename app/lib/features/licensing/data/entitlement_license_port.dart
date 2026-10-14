import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// APP-03's Settings "License" hook over LIC-01's [EntitlementService]
/// (integration wave 2). The summary reflects the *effective* plan; the
/// restore / enterprise actions stay unavailable until LIC-02 / LIC-03
/// provide their sources.
class EntitlementLicensePort implements LicenseSettingsPort {
  const EntitlementLicensePort(this._entitlements);

  final EntitlementService _entitlements;

  static LicenseSummary summaryOf(FeatureAccess a) => LicenseSummary(
    tier: switch (a.effectivePlan.tier) {
      Tier.free => LicenseTier.free,
      Tier.pro => LicenseTier.pro,
      Tier.enterprise => LicenseTier.enterprise,
    },
    expiresAt: a.effectivePlan == Plan.free ? null : a.entitlement.expiresAt,
  );

  @override
  Stream<LicenseSummary> watch() async* {
    yield summaryOf(_entitlements.access);
    yield* _entitlements.changes.map(summaryOf);
  }

  @override
  Future<Result<void>> restorePurchases() async =>
      const Err(UnsupportedFeatureFailure('purchases'));

  @override
  Future<Result<void>> installEnterpriseLicense(String license) async =>
      const Err(UnsupportedFeatureFailure('enterprise licence'));
}
