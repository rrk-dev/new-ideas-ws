import 'package:vaultvoice/features/licensing/domain/entitlement.dart';

/// The [Feature] that gates built-in profile [profileId] in the profile
/// picker, or null when the profile is available in every tier. Gating itself
/// stays in `kFeatureMatrix` / `FeatureGate`; this only names the row.
///
/// PRODUCT-DECISION: only Warranty and Engineering have matrix rows (LIC-01).
/// Meeting, Lecture, Sales call and Interview are ungated for now, as no Pro
/// tier is enforced; add a [Feature] and a case here if that changes.
Feature? featureForProfile(String profileId) => switch (profileId) {
  'warranty' => Feature.builtinWarranty,
  'engineering' => Feature.builtinEngineering,
  _ => null,
};
