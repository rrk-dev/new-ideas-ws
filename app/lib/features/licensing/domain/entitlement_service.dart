import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';

/// The single authority on what the user may do (LIC-01).
///
/// UI and features use `featureProvider(Feature.x)`; only this service and
/// the entitlement sources (LIC-02 store purchases, LIC-03 enterprise
/// licences) look at [Plan]s.
abstract interface class EntitlementService {
  /// Current snapshot, resolved against the clock.
  FeatureAccess get access;

  /// Emits a new snapshot whenever the entitlement changes or expires.
  Stream<FeatureAccess> get changes;

  /// Shortcut for `access.has(feature)`.
  bool has(Feature feature);

  /// Replaces the stored entitlement (called by verification sources).
  void update(Entitlement entitlement);

  /// Re-evaluates the entitlement against the clock (e.g. on app resume, in
  /// case the wall clock jumped past an expiry).
  void refresh();

  Future<void> dispose();
}
