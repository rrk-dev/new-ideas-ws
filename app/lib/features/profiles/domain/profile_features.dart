import 'package:vaultvoice/features/licensing/domain/entitlement.dart';

/// The [Feature] that gates built-in profile [profileId] in the profile
/// picker, or null when the profile is available in every tier. Gating itself
/// stays in `kFeatureMatrix` / `FeatureGate`; this only names the row.
///
/// Meeting is the always-free baseline. Every other built-in has a matrix row
/// (LIC-01, LIC-05); the rows are open to everyone while no Pro tier is
/// enforced (`kProTierEnforced`).
Feature? featureForProfile(String profileId) => switch (profileId) {
  'warranty' => Feature.builtinWarranty,
  'engineering' => Feature.builtinEngineering,
  'lecture' => Feature.lectureProfile,
  'sales_call' => Feature.salesProfile,
  'interview' => Feature.interviewProfile,
  _ => null,
};
