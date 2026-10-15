import 'dart:async';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';

class FakePurchaseStore implements PurchaseStore {
  @override
  EntitlementSource source = EntitlementSource.appStore;
  final events = StreamController<void>.broadcast();
  Result<List<StoreOwnership>> owned = const Ok([]);
  Result<PurchaseOutcome> outcome = const Ok(PurchaseOutcome.purchased);
  Result<void> restored = const Ok(null);
  int queries = 0;
  int restores = 0;
  final purchases = <String>[];
  List<StoreProduct> catalog = const [
    StoreProduct(id: annualProductId, price: 'STORE ANNUAL'),
    StoreProduct(id: lifetimeProductId, price: 'STORE LIFETIME'),
  ];
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<Result<List<StoreProduct>>> products() async => Ok(catalog);
  @override
  Future<Result<List<StoreOwnership>>> currentEntitlements() async {
    queries++;
    return owned;
  }

  @override
  Future<Result<PurchaseOutcome>> purchase(String productId) async {
    purchases.add(productId);
    return outcome;
  }

  @override
  Future<Result<void>> restore() async {
    restores++;
    return restored;
  }

  @override
  Future<void> dispose() => events.close();
}
