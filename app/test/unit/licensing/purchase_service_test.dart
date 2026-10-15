import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/data/purchase_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_purchase_store.dart';
import '../../fakes/fake_settings_store.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14);
  for (final source in [
    EntitlementSource.appStore,
    EntitlementSource.googlePlay,
  ]) {
    group(source.name, () {
      late FakeClock clock;
      late FakePurchaseStore store;
      late FakeSettingsStore settings;
      late LocalEntitlementService entitlements;
      late PurchaseService service;
      setUp(() {
        clock = FakeClock(now);
        store = FakePurchaseStore()..source = source;
        settings = FakeSettingsStore();
        entitlements = LocalEntitlementService(
          clock: clock,
          mode: DistributionMode.commercial,
        );
        service = PurchaseService(
          store: store,
          settings: settings,
          entitlements: entitlements,
          clock: clock,
        );
      });
      tearDown(() async {
        await service.dispose();
        await entitlements.dispose();
      });

      test(
        '[LIC-02/AC1] launch, purchase, renewal, expiry, refund and restore',
        () async {
          await service.start();
          expect(entitlements.access.effectivePlan, Plan.free);
          store.owned = Ok([
            StoreOwnership(
              annualProductId,
              expiresAt: now.add(const Duration(days: 10)),
            ),
          ]);
          expect(
            await service.purchase(annualProductId),
            isA<Ok<PurchaseOutcome>>(),
          );
          expect(entitlements.access.effectivePlan, Plan.proAnnual);
          final renewed = now.add(const Duration(days: 375));
          store.owned = Ok([
            StoreOwnership(annualProductId, expiresAt: renewed),
          ]);
          await service.refresh();
          expect(entitlements.access.entitlement.expiresAt, renewed);
          store.owned = Ok([StoreOwnership(annualProductId, expiresAt: now)]);
          await service.refresh();
          expect(entitlements.access.effectivePlan, Plan.free);
          store.owned = const Ok([StoreOwnership(lifetimeProductId)]);
          await service.restore();
          expect(store.restores, 1);
          expect(entitlements.access.effectivePlan, Plan.proLifetime);
          store.owned = const Ok([]);
          await service.refresh();
          expect(entitlements.access.effectivePlan, Plan.free);
          store.owned = const Err(UnsupportedFeatureFailure('offline'));
          await service.refresh();
          expect(entitlements.access.effectivePlan, Plan.free);
        },
      );

      test(
        '[LIC-02/AC1] pending and cancellation never grant or query ownership',
        () async {
          await service.start();
          for (final result in [
            PurchaseOutcome.pending,
            PurchaseOutcome.cancelled,
          ]) {
            store
              ..outcome = Ok(result)
              ..owned = const Ok([StoreOwnership(lifetimeProductId)]);
            await service.purchase(annualProductId);
            expect(entitlements.access.effectivePlan, Plan.free);
          }
          expect(store.queries, 1);
        },
      );

      test('[LIC-02/AC1] verified lifetime wins; revocation falls back to annual; invalid verification clears cache', () async {
        store.owned = Ok([
          const StoreOwnership(lifetimeProductId),
          StoreOwnership(
            annualProductId,
            expiresAt: now.add(const Duration(days: 10)),
          ),
        ]);
        await service.start();
        expect(entitlements.access.effectivePlan, Plan.proLifetime);
        store.owned = Ok([
          StoreOwnership(
            annualProductId,
            expiresAt: now.add(const Duration(days: 10)),
          ),
        ]);
        await service.refresh();
        expect(entitlements.access.effectivePlan, Plan.proAnnual);
        store.owned = const Err(NativeFailure(1, 'store verification'));
        await service.refresh();
        expect(entitlements.access.effectivePlan, Plan.free);
      });

      test(
        '[LIC-02/AC1] invalid verification and missing ownership cannot report '
        'a successful purchase or restore',
        () async {
          await service.start();
          store.owned = const Err(NativeFailure(1, 'store verification'));
          expect(
            await service.purchase(lifetimeProductId),
            isA<Err<PurchaseOutcome>>(),
          );
          expect(entitlements.access.effectivePlan, Plan.free);
          store.restored = const Err(NativeFailure(1, 'store verification'));
          expect(await service.restore(), isA<Err<void>>());
          store.owned = const Ok([]);
          expect(
            await service.purchase(lifetimeProductId),
            isA<Err<PurchaseOutcome>>(),
          );
          expect(entitlements.access.effectivePlan, Plan.free);
        },
      );

      test(
        '[LIC-02/AC1] listener refreshes after unsolicited refund',
        () async {
          store.owned = const Ok([StoreOwnership(lifetimeProductId)]);
          await service.start();
          store.owned = const Ok([]);
          store.events.add(null);
          await Future<void>.delayed(Duration.zero);
          await service.refresh();
          expect(entitlements.access.effectivePlan, Plan.free);
          expect(store.queries, greaterThanOrEqualTo(3));
        },
      );

      test('[LIC-02/AC2] outage preserves cache and verification time across restart', () async {
        final expiry = now.add(const Duration(days: 2));
        store.owned = Ok([StoreOwnership(annualProductId, expiresAt: expiry)]);
        await service.start();
        clock.advance(const Duration(days: 3));
        store.owned = const Err(UnsupportedFeatureFailure('offline'));
        await service.refresh();
        expect(entitlements.access.effectivePlan, Plan.proAnnual);
        expect(entitlements.access.entitlement.verifiedAt, now);
        final cached = await settings.watch(purchaseCacheKey).first;
        final secondStore = FakePurchaseStore()
          ..source = source
          ..owned = store.owned;
        final second = PurchaseService(
          store: secondStore,
          settings: settings,
          entitlements: entitlements,
          clock: clock,
        );
        await second.start();
        expect(entitlements.access.effectivePlan, Plan.proAnnual);
        expect(await settings.watch(purchaseCacheKey).first, cached);
        clock.advance(const Duration(days: 27));
        await second.refresh();
        expect(entitlements.access.effectivePlan, Plan.free);
        await second.dispose();
      });
    });
  }

  test('[LIC-02/AC2] strict dual grace boundaries and future verification fail closed', () {
    final verified = VerifiedPurchase(
      plan: Plan.proAnnual,
      source: EntitlementSource.appStore,
      verifiedAt: now,
      expiresAt: now.subtract(const Duration(days: 2)),
    );
    final limit = now.add(const Duration(days: 28));
    expect(
      verified
          .resolve(
            limit.subtract(const Duration(milliseconds: 1)),
            unavailable: true,
          )
          .effectivePlanAt(limit.subtract(const Duration(milliseconds: 1))),
      Plan.proAnnual,
    );
    expect(
      verified.resolve(limit, unavailable: true).effectivePlanAt(limit),
      Plan.free,
    );
    expect(
      verified
          .resolve(now.subtract(const Duration(seconds: 1)), unavailable: true)
          .plan,
      Plan.free,
    );
    expect(
      verified.resolve(now, unavailable: false).effectivePlanAt(now),
      Plan.free,
    );
  });

  test('[LIC-02/AC2] lifetime survives outages and JSON roundtrip; unknown products do not grant', () {
    final verified = verifiedSnapshot(
      const [StoreOwnership(lifetimeProductId)],
      now,
      EntitlementSource.appStore,
    );
    final later = now.add(const Duration(days: 2000));
    expect(
      VerifiedPurchase.fromJson(verified.toJson())
          .resolve(later, unavailable: true)
          .effectivePlanAt(later),
      Plan.proLifetime,
    );
    expect(
      verifiedSnapshot(
        const [StoreOwnership('unknown')],
        now,
        EntitlementSource.appStore,
      ).plan,
      Plan.free,
    );
  });
}
