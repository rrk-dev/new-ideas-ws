import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/data/platform_purchase_store.dart';
import 'package:vaultvoice/features/licensing/data/purchase_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'purchase_providers.g.dart';

@Riverpod(keepAlive: true)
PurchaseStore purchaseStore(Ref ref) => PlatformPurchaseStore(
  source: Platform.isAndroid
      ? EntitlementSource.googlePlay
      : EntitlementSource.appStore,
);

@Riverpod(keepAlive: true)
PurchaseService purchaseService(Ref ref) {
  final service = PurchaseService(
    store: ref.watch(purchaseStoreProvider),
    settings: ref.watch(settingsStoreProvider),
    entitlements: ref.watch(entitlementServiceProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@riverpod
Future<List<StoreProduct>> storeProducts(Ref ref) async =>
    (await ref.watch(purchaseStoreProvider).products()).valueOrNull ?? const [];
