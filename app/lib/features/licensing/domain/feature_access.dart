import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// How a piece of user-created or installed content may be used under the
/// current entitlement.
enum AccessLevel {
  /// Usable and editable.
  full,

  /// Kept and visible, but cannot be edited or newly used (downgrade).
  readOnly,

  /// Kept on disk / in the DB but switched off (e.g. extra vault targets).
  disabled,
}

/// Immutable snapshot of what the user may do right now: the effective plan
/// resolved against the clock, and the feature set it unlocks.
///
/// Downgrade rules (vv-licensing-iap): nothing the user created is deleted.
/// Custom profiles/templates/routing rules become read-only, vault targets
/// beyond the first are disabled, Pro-only models stay installed but cannot
/// be selected.
final class FeatureAccess {
  FeatureAccess._({
    required this.entitlement,
    required this.effectivePlan,
    required this.mode,
    required this.proTierEnforced,
    required this.features,
  });

  /// Resolves [entitlement] at [now] in [mode].
  factory FeatureAccess.resolve(
    Entitlement entitlement, {
    required DateTime now,
    required DistributionMode mode,
    bool proTierEnforced = true,
  }) {
    final active = entitlement.isActiveAt(now);
    final plan = entitlement.effectivePlanAt(now);
    return FeatureAccess._(
      entitlement: entitlement,
      effectivePlan: plan,
      mode: mode,
      proTierEnforced: proTierEnforced,
      features: Set.unmodifiable({
        for (final f in Feature.values)
          if (featureEnabled(f, plan, mode, proTierEnforced: proTierEnforced))
            f,
        if (active) ...entitlement.extraFeatures,
      }),
    );
  }

  /// The stored entitlement (may be expired).
  final Entitlement entitlement;

  /// The plan in force (Free once a subscription/licence has lapsed).
  final Plan effectivePlan;

  final DistributionMode mode;

  /// Whether the Pro column of the matrix is enforced (LIC-05).
  final bool proTierEnforced;

  /// Enabled features.
  final Set<Feature> features;

  bool has(Feature feature) => features.contains(feature);

  /// The user paid for more than currently applies (expired / lapsed).
  bool get isDowngraded => effectivePlan != entitlement.plan;

  /// Whether gated features should lead to a paywall (commercial builds
  /// with the Pro tier enforced only; otherwise none is ever shown).
  bool get paywallEnabled =>
      mode == DistributionMode.commercial && proTierEnforced;

  /// Maximum number of active vault targets (`null` = unlimited).
  int? get maxActiveVaultTargets => has(Feature.multiTarget) ? null : 1;

  /// Access to an existing custom profile.
  AccessLevel get customProfiles => _readOnlyUnless(Feature.customProfiles);

  /// Access to an existing custom template.
  AccessLevel get customTemplates => _readOnlyUnless(Feature.customTemplates);

  /// Access to existing routing rules (kept, not applied while read-only:
  /// notes go to the first target).
  AccessLevel get routingRules => _readOnlyUnless(Feature.routingRules);

  /// Access to the vault target at [index] in the user's ordered list. The
  /// first target always stays usable.
  AccessLevel vaultTarget(int index) {
    final max = maxActiveVaultTargets;
    return max == null || index < max ? AccessLevel.full : AccessLevel.disabled;
  }

  /// Access to a catalog model of [tier]. Not entitled + installed ⇒ kept
  /// but not selectable ([AccessLevel.readOnly]); not entitled + not
  /// installed ⇒ cannot be downloaded ([AccessLevel.disabled]).
  AccessLevel model(ModelTier tier, {required bool installed}) {
    final max = maxModelTier(
      effectivePlan,
      mode,
      proTierEnforced: proTierEnforced,
    );
    if (tier.index <= max.index) {
      return AccessLevel.full;
    }
    return installed ? AccessLevel.readOnly : AccessLevel.disabled;
  }

  AccessLevel _readOnlyUnless(Feature f) =>
      has(f) ? AccessLevel.full : AccessLevel.readOnly;
}
