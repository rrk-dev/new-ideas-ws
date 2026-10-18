import 'package:vaultvoice/features/licensing/domain/entitlement.dart';

/// Where in the app the user hit a gated feature (paywall analytics are
/// *not* collected — this only lets the paywall explain the context).
enum PaywallEntryPoint {
  modelPicker,
  profileEditor,
  profilePicker,
  templateEditor,
  vaultTargets,
  routingRules,
  modelSideload,
  mindMap,
  ask,
  reminders,
  settings,
}

/// A request to show the upgrade screen for [feature].
final class PaywallRequest {
  const PaywallRequest({required this.feature, required this.entryPoint});

  final Feature feature;
  final PaywallEntryPoint entryPoint;
}

/// Shows the paywall. LIC-02 provides the real store-backed implementation;
/// until then [NoPaywallPresenter] is used.
abstract interface class PaywallPresenter {
  /// Completes when the paywall is dismissed. The new entitlement (if the
  /// user bought something) arrives through the EntitlementService.
  Future<void> show(PaywallRequest request);
}

/// Default presenter: there is nothing to buy yet (no store code in LIC-01).
class NoPaywallPresenter implements PaywallPresenter {
  const NoPaywallPresenter();

  @override
  Future<void> show(PaywallRequest request) async {}
}
