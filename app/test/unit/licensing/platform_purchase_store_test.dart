import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/data/platform_purchase_store.dart';
import 'package:vaultvoice/features/licensing/data/purchase_api.g.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  BasicMessageChannel<Object?> channel(String method) =>
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.vaultvoice.PurchaseHostApi.$method',
        PurchaseHostApi.pigeonChannelCodec,
      );
  late PlatformPurchaseStore store;
  setUp(() {
    store = PlatformPurchaseStore(source: EntitlementSource.appStore);
  });
  tearDown(() async {
    for (final method in [
      'products',
      'currentEntitlements',
      'purchase',
      'restore',
    ]) {
      messenger.setMockDecodedMessageHandler<Object?>(channel(method), null);
    }
    await store.dispose();
  });

  testWidgets('[LIC-02/AC1] purchase sheet can wait beyond query timeout', (
    tester,
  ) async {
    final response = Completer<Object?>();
    messenger.setMockDecodedMessageHandler<Object?>(
      channel('purchase'),
      (_) => response.future,
    );
    Result<PurchaseOutcome>? result;
    final purchase = store.purchase(annualProductId).then((value) {
      result = value;
    });
    await tester.pump(const Duration(seconds: 31));
    expect(result, isNull);
    response.complete([StorePurchaseOutcome.purchased]);
    await tester.pump();
    await purchase;
    expect(result!.valueOrNull, PurchaseOutcome.purchased);
  });

  test('[LIC-02/AC1] typed bridge preserves store price and verified expiration; filters unknown products', () async {
    messenger.setMockDecodedMessageHandler<Object?>(
      channel('products'),
      (_) async => [
        [
          StoreProductMessage(
            id: annualProductId,
            price: 'localized-store-price',
          ),
          StoreProductMessage(id: 'unknown', price: 'ignored'),
        ],
      ],
    );
    final products = (await store.products()).valueOrNull!;
    expect(products.single.price, 'localized-store-price');
    final expiry = DateTime.utc(2027);
    messenger.setMockDecodedMessageHandler<Object?>(
      channel('currentEntitlements'),
      (_) async => [
        [
          StoreEntitlementMessage(
            productId: annualProductId,
            expiresAtMs: expiry.millisecondsSinceEpoch,
          ),
        ],
      ],
    );
    expect(
      (await store.currentEntitlements()).valueOrNull!.single.expiresAt,
      expiry,
    );
  });

  test('[LIC-02/AC1] invalid signature differs from unavailable store and purchase outcomes survive codec', () async {
    messenger.setMockDecodedMessageHandler<Object?>(
      channel('currentEntitlements'),
      (_) async => ['verification_failed', 'redacted', null],
    );
    expect(
      await store.currentEntitlements(),
      isA<Err<List<StoreOwnership>>>().having(
        (r) => r.failure,
        'verification failure',
        isA<NativeFailure>().having((f) => f.code, 'denial code', 1),
      ),
    );
    messenger.setMockDecodedMessageHandler<Object?>(
      channel('currentEntitlements'),
      (_) async => ['unavailable', 'redacted', null],
    );
    expect(
      await store.currentEntitlements(),
      isA<Err<List<StoreOwnership>>>().having(
        (r) => r.failure,
        'offline failure',
        isA<UnsupportedFeatureFailure>(),
      ),
    );
    for (final outcome in StorePurchaseOutcome.values) {
      messenger.setMockDecodedMessageHandler<Object?>(
        channel('purchase'),
        (_) async => [outcome],
      );
      expect(
        (await store.purchase(annualProductId)).valueOrNull!.name,
        outcome.name,
      );
    }
    messenger.setMockDecodedMessageHandler<Object?>(
      channel('restore'),
      (_) async => [null],
    );
    expect((await store.restore()).isOk, isTrue);
  });
}
