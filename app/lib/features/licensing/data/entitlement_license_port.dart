import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// APP-03's Settings "License" hook over LIC-01's [EntitlementService]
/// (integration wave 2). The summary reflects the *effective* plan;
/// LIC-02 supplies store restore through [restore]. Enterprise remains
/// unavailable (outside v1 scope).
class EntitlementLicensePort implements LicenseSettingsPort {
  const EntitlementLicensePort(this._entitlements, {this.restore});

  final Future<Result<void>> Function()? restore;

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
  Future<Result<void>> restorePurchases() async => restore == null
      ? const Err(UnsupportedFeatureFailure('purchases'))
      : await restore!();

  @override
  Future<Result<void>> installEnterpriseLicense(String license) async =>
      const Err(UnsupportedFeatureFailure('enterprise licence'));
}
