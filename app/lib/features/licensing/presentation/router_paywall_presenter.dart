import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';

/// Navigation only; store state arrives through EntitlementService.
class RouterPaywallPresenter implements PaywallPresenter {
  const RouterPaywallPresenter(this.router);
  final GoRouter router;
  @override
  Future<void> show(PaywallRequest request) async {
    await router.push<void>(const ProRoute().location);
  }
}
