import 'package:vaultvoice/features/licensing/data/purchase_providers.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';
import 'package:vaultvoice/features/licensing/presentation/paywall_screen.dart';

import '../helpers/golden.dart';

void main() {
  goldenTest(
    '[LIC-02] store paywall',
    fileName: 'paywall',
    overrides: [
      storeProductsProvider.overrideWith(
        (ref) async => const [
          // Synthetic display strings only.
          // Production prices always come from the store.
          StoreProduct(id: annualProductId, price: 'TEST 12.00'),
          StoreProduct(id: lifetimeProductId, price: 'TEST 34.00'),
        ],
      ),
    ],
    builder: (_) => const PaywallScreen(),
  );
}
