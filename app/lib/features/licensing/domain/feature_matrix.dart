import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Whether this build sells tiers at all.
///
/// Store releases pass `--dart-define=VV_COMMERCIAL=true` (LIC-02).
/// Development builds default to personal access; explicit commercial dev
/// builds exercise the store paywall. The product uses annual/lifetime Pro.
enum DistributionMode {
  /// Personal / self-use build (default): everything except organisation
  /// management is unlocked; no paywall.
  personal,

  /// Store build with Free / Pro / Enterprise tiers (master plan §7).
  commercial,
}

/// `VV_COMMERCIAL` dart-define; `false` unless set at build time.
const bool kCommercialBuild = bool.fromEnvironment('VV_COMMERCIAL');

/// `VV_PRO_ENFORCED` dart-define (LIC-05). `false` unless set at build time.
///
/// PRODUCT-DECISION (product owner, 2026-10-17): there is no Pro tier for
/// now. While this is `false`, every Pro column of [kFeatureMatrix] is open
/// to everyone and no paywall is shown. Build with
/// `--dart-define=VV_PRO_ENFORCED=true` (together with `VV_COMMERCIAL=true`)
/// to enforce the tiers recorded in the matrix.
const bool kProTierEnforced = bool.fromEnvironment('VV_PRO_ENFORCED');

/// One row of the matrix: which tier columns enable a feature in a
/// commercial build, and whether a personal build enables it.
final class FeatureRow {
  const FeatureRow({
    required this.free,
    required this.pro,
    required this.enterprise,
    required this.personal,
  });

  final bool free;
  final bool pro;
  final bool enterprise;

  /// Personal builds ignore the commercial columns (except that Enterprise
  /// still gets every enterprise feature when a licence is present).
  final bool personal;

  bool forTier(Tier tier) => switch (tier) {
    Tier.free => free,
    Tier.pro => pro,
    Tier.enterprise => enterprise,
  };
}

/// THE feature × tier table (master plan §7, vv-licensing-iap). No other
/// code decides what a plan can do. Every cell has a unit test
/// (`test/unit/licensing/feature_matrix_test.dart`).
const Map<Feature, FeatureRow> kFeatureMatrix = {
  // PRODUCT-DECISION: master plan §7 gives Free "small/tiny Whisper"; the
  // skills default `small`/`small.en` to Pro. Conservative default: Pro.
  Feature.smallStt: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: §7 — high-accuracy Whisper is Pro.
  Feature.highAccuracyStt: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: Free LLM is capped at the 1B-class model on every
  // device tier; 3B+ is Pro (§7).
  Feature.largeLlm: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: §7 — custom templates are Pro.
  Feature.customTemplates: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: §7 — unlimited / custom profiles are Pro; Free has
  // the built-in Meeting profile only.
  Feature.customProfiles: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: §7 — Free has one vault target.
  Feature.multiTarget: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: §7 — multiple routing rules are Pro.
  Feature.routingRules: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION (open question in LIC-01): §7 lists Warranties under
  // Pro, so the built-in Warranty profile defaults to Pro.
  Feature.builtinWarranty: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION (open question in LIC-01): Engineering profile tier is
  // unspecified in §7; defaults to Pro like Warranty.
  Feature.builtinEngineering: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: managed profiles/config need an enterprise licence in
  // every build (they only make sense with an organisation behind them).
  Feature.managedProfiles: FeatureRow(
    free: false,
    pro: false,
    enterprise: true,
    personal: false,
  ),
  // PRODUCT-DECISION: sideloading custom models is a Pro power-user
  // feature (MDM may still disable it — LIC-04 `disable_custom_models`).
  Feature.sideloadCustomModel: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // Phase 2 (LIC-05). PRODUCT-DECISION 2026-10-17: the columns below are the
  // intended future tiers; none is enforced while [kProTierEnforced] is off.
  // Quick capture only opens the recorder (navigate-only, ADR-QCP-01): Free.
  Feature.quickCapture: FeatureRow(
    free: true,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: the Lecture, Sales call and Interview built-in profiles
  // follow Warranty / Engineering: Pro.
  Feature.lectureProfile: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  Feature.salesProfile: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  Feature.interviewProfile: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: Ask needs the 3B model (`Feature.largeLlm`, Pro by the
  // size rule), so the feature itself is Pro as well.
  Feature.askNotes: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: mind maps are a Pro output.
  Feature.mindMap: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
  // PRODUCT-DECISION: Apple Reminders export is a Pro integration.
  Feature.remindersExport: FeatureRow(
    free: false,
    pro: true,
    enterprise: true,
    personal: true,
  ),
};

/// Whether [feature] is enabled for [plan] (already the *effective* plan)
/// in [mode].
///
/// With [proTierEnforced] off (the shipped default, see [kProTierEnforced])
/// the Pro column is open to every plan; enterprise-only rows stay closed.
bool featureEnabled(
  Feature feature,
  Plan plan,
  DistributionMode mode, {
  bool proTierEnforced = true,
}) {
  final row = kFeatureMatrix[feature]!;
  return switch (mode) {
    DistributionMode.commercial =>
      row.forTier(plan.tier) || (!proTierEnforced && row.pro),
    // An enterprise licence keeps its enterprise-only extras in a personal
    // build; everything else follows the personal column.
    DistributionMode.personal =>
      row.personal || (plan.tier == Tier.enterprise && row.enterprise),
  };
}

/// Highest catalog [ModelTier] that may be selected/downloaded.
///
/// PRODUCT-DECISION: Pro-tier catalog models follow the Pro column;
/// enterprise-tier models need an enterprise licence in every build.
ModelTier maxModelTier(
  Plan plan,
  DistributionMode mode, {
  bool proTierEnforced = true,
}) => switch ((plan.tier, mode)) {
  (Tier.enterprise, _) => ModelTier.enterprise,
  (Tier.pro, _) || (Tier.free, DistributionMode.personal) => ModelTier.pro,
  (Tier.free, DistributionMode.commercial) =>
    proTierEnforced ? ModelTier.free : ModelTier.pro,
};
