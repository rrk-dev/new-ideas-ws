/// What the user has bought / been licensed (LIC-01).
///
/// Only `features/licensing` inspects plans. Everything else asks
/// `featureProvider(Feature.x)` (vv-licensing-iap).
enum Plan { free, proAnnual, proLifetime, enterprise }

/// The capability tiers of the feature matrix. Both Pro plans share one
/// column: annual vs lifetime only differ in expiry.
enum Tier { free, pro, enterprise }

extension PlanTier on Plan {
  Tier get tier => switch (this) {
    Plan.free => Tier.free,
    Plan.proAnnual || Plan.proLifetime => Tier.pro,
    Plan.enterprise => Tier.enterprise,
  };
}

/// Gated capabilities. The baseline (tiny/base Whisper, the 1B-class LLM,
/// the built-in Meeting profile, one vault target) is always available and
/// therefore has no flag.
enum Feature {
  /// Whisper `small` / `small.en` (master plan §7 vs skills default — see
  /// the PRODUCT-DECISION in `feature_matrix.dart`).
  smallStt,

  /// High-accuracy Whisper (medium / large-v3-turbo).
  highAccuracyStt,

  /// LLMs above the 1B class (3B+).
  largeLlm,

  /// User-authored Markdown templates.
  customTemplates,

  /// User-authored extraction profiles (unlimited).
  customProfiles,

  /// More than one vault target.
  multiTarget,

  /// Routing rules (send notes to different targets by profile/tag).
  routingRules,

  /// Built-in Warranty profile.
  builtinWarranty,

  /// Built-in Engineering profile.
  builtinEngineering,

  /// Organisation-managed profiles/templates/config (LIC-03/LIC-04).
  managedProfiles,

  /// Sideloading a custom (non-catalog) model file.
  sideloadCustomModel,

  /// Quick capture entry points (widget, Lock Screen control, tile, shortcut).
  quickCapture,

  /// Built-in Lecture profile.
  lectureProfile,

  /// Built-in Sales call profile.
  salesProfile,

  /// Built-in Interview profile.
  interviewProfile,

  /// Ask your notes (the 3B model itself is [largeLlm]).
  askNotes,

  /// Mind map generation, viewer and export.
  mindMap,

  /// Apple Reminders export of action items.
  remindersExport,
}

/// Where an [Entitlement] came from. Store/licence sources are produced by
/// LIC-02 / LIC-03; this task only ships [builtIn].
enum EntitlementSource { builtIn, appStore, googlePlay, enterpriseLicense }

/// The last known entitlement of this install. Immutable; a source replaces
/// it with a new value after each (re-)verification.
///
/// Offline grace (LIC-02) and licence grace (LIC-03) are applied by those
/// sources when they compute [expiresAt]; this class only compares the
/// clock against it.
final class Entitlement {
  const Entitlement({
    required this.plan,
    required this.verifiedAt,
    required this.source,
    this.expiresAt,
    this.extraFeatures = const {},
  });

  /// The default for every install: Free, nothing to verify.
  Entitlement.free(DateTime at)
    : this(plan: Plan.free, verifiedAt: at, source: EntitlementSource.builtIn);

  final Plan plan;

  /// End of the paid period. Required for [Plan.proAnnual] and
  /// [Plan.enterprise] — a missing expiry counts as expired (fail closed);
  /// ignored for [Plan.free] and [Plan.proLifetime].
  final DateTime? expiresAt;

  /// Time of the last successful verification.
  final DateTime verifiedAt;

  final EntitlementSource source;

  /// Extra features granted on top of the plan (e.g. an enterprise licence
  /// `features[]`). Only honoured while the entitlement is active.
  final Set<Feature> extraFeatures;

  /// Whether the paid plan is in force at [now].
  bool isActiveAt(DateTime now) => switch (plan) {
    Plan.free || Plan.proLifetime => true,
    Plan.proAnnual ||
    Plan.enterprise => expiresAt != null && now.isBefore(expiresAt!),
  };

  /// The plan that actually applies at [now]: an expired subscription or
  /// licence falls back to [Plan.free] (graceful downgrade, nothing deleted).
  Plan effectivePlanAt(DateTime now) => isActiveAt(now) ? plan : Plan.free;

  /// The next instant at which [effectivePlanAt] changes, if any.
  DateTime? nextChangeAfter(DateTime now) =>
      isActiveAt(now) && plan != Plan.free && plan != Plan.proLifetime
      ? expiresAt
      : null;

  /// Value equality (kept as a method: domain code has no `@immutable`).
  bool sameAs(Entitlement other) =>
      other.plan == plan &&
      other.expiresAt == expiresAt &&
      other.verifiedAt == verifiedAt &&
      other.source == source &&
      other.extraFeatures.length == extraFeatures.length &&
      other.extraFeatures.containsAll(extraFeatures);

  @override
  String toString() =>
      'Entitlement(${plan.name}, expires: $expiresAt, '
      'source: ${source.name})';
}
