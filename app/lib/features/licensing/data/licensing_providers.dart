import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/router_paywall_presenter.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

part 'licensing_providers.g.dart';

/// Personal vs commercial build (`--dart-define=VV_COMMERCIAL=true`).
/// PRODUCT-DECISION: defaults to [DistributionMode.personal]; tests override.
@Riverpod(keepAlive: true)
DistributionMode distributionMode(Ref ref) =>
    kCommercialBuild ? DistributionMode.commercial : DistributionMode.personal;

/// LIC-05 switch: whether the Pro column is enforced (`VV_PRO_ENFORCED`).
/// PRODUCT-DECISION: `false` — no Pro tier for now. Tests override.
@Riverpod(keepAlive: true)
bool proTierEnforced(Ref ref) => kProTierEnforced;

/// The one entitlement authority. LIC-02/LIC-03 sources call
/// `EntitlementService.update` after each verification.
@Riverpod(keepAlive: true)
EntitlementService entitlementService(Ref ref) {
  final service = LocalEntitlementService(
    clock: ref.watch(clockProvider),
    mode: ref.watch(distributionModeProvider),
    proTierEnforced: ref.watch(proTierEnforcedProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Current [FeatureAccess], updated on every entitlement change/expiry.
@Riverpod(keepAlive: true)
class FeatureAccessState extends _$FeatureAccessState {
  @override
  FeatureAccess build() {
    final service = ref.watch(entitlementServiceProvider);
    final sub = service.changes.listen((a) => state = a);
    ref.onDispose(sub.cancel);
    return service.access;
  }
}

/// `ref.watch(featureProvider(Feature.x))` — the only feature check UI and
/// features should use.
@riverpod
bool feature(Ref ref, Feature feature) =>
    ref.watch(featureAccessStateProvider.select((a) => a.has(feature)));

/// Access to an installed / downloadable catalog model of [tier].
@riverpod
AccessLevel modelAccess(Ref ref, ModelTier tier, {required bool installed}) =>
    ref.watch(
      featureAccessStateProvider.select(
        (a) => a.model(tier, installed: installed),
      ),
    );

/// What Settings shows about the licence (hook for the Settings screen;
/// LIC-01 does not build that UI).
@immutable
final class EntitlementSummary {
  const EntitlementSummary({
    required this.plan,
    required this.effectivePlan,
    required this.expiresAt,
    required this.mode,
    required this.isDowngraded,
  });

  /// What was bought / licensed.
  final Plan plan;

  /// What applies now.
  final Plan effectivePlan;
  final DateTime? expiresAt;
  final DistributionMode mode;
  final bool isDowngraded;

  @override
  bool operator ==(Object other) =>
      other is EntitlementSummary &&
      other.plan == plan &&
      other.effectivePlan == effectivePlan &&
      other.expiresAt == expiresAt &&
      other.mode == mode &&
      other.isDowngraded == isDowngraded;

  @override
  int get hashCode =>
      Object.hash(plan, effectivePlan, expiresAt, mode, isDowngraded);
}

@riverpod
EntitlementSummary entitlementSummary(Ref ref) {
  final a = ref.watch(featureAccessStateProvider);
  return EntitlementSummary(
    plan: a.entitlement.plan,
    effectivePlan: a.effectivePlan,
    expiresAt: a.entitlement.expiresAt,
    mode: a.mode,
    isDowngraded: a.isDowngraded,
  );
}

/// Paywall entry point opens the typed store-backed screen.
@Riverpod(keepAlive: true)
PaywallPresenter paywallPresenter(Ref ref) =>
    RouterPaywallPresenter(ref.watch(appRouterProvider));
