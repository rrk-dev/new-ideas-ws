import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/data/purchase_api.g.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';

class PlatformPurchaseStore implements PurchaseStore, PurchaseFlutterApi {
  PlatformPurchaseStore({required this.source, PurchaseHostApi? api})
    : _api = api ?? PurchaseHostApi() {
    PurchaseFlutterApi.setUp(this);
  }
  final PurchaseHostApi _api;
  @override
  final EntitlementSource source;
  final _changes = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Future<void> changed() async {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action().timeout(const Duration(seconds: 30)));
    } on PlatformException catch (e) {
      return Err(
        e.code == 'verification_failed'
            ? const NativeFailure(1, 'store verification')
            : const UnsupportedFeatureFailure('store unavailable'),
      );
    } on Object {
      return const Err(UnsupportedFeatureFailure('store unavailable'));
    }
  }

  @override
  Future<Result<List<StoreProduct>>> products() => _call(
    () async => [
      for (final p in await _api.products())
        if (p.id == annualProductId || p.id == lifetimeProductId)
          StoreProduct(id: p.id, price: p.price),
    ],
  );
  @override
  Future<Result<List<StoreOwnership>>> currentEntitlements() => _call(
    () async => [
      for (final p in await _api.currentEntitlements())
        StoreOwnership(
          p.productId,
          expiresAt: p.expiresAtMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  p.expiresAtMs!,
                  isUtc: true,
                ),
        ),
    ],
  );
  @override
  Future<Result<PurchaseOutcome>> purchase(String productId) => _call(
    () async => switch (await _api.purchase(productId)) {
      StorePurchaseOutcome.purchased => PurchaseOutcome.purchased,
      StorePurchaseOutcome.pending => PurchaseOutcome.pending,
      StorePurchaseOutcome.cancelled => PurchaseOutcome.cancelled,
    },
  );
  @override
  Future<Result<void>> restore() => _call(_api.restore);
  @override
  Future<void> dispose() async {
    PurchaseFlutterApi.setUp(null);
    await _changes.close();
  }
}
