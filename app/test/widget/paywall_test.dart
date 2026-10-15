import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/data/purchase_providers.dart';
import 'package:vaultvoice/features/licensing/data/purchase_service.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';
import 'package:vaultvoice/features/licensing/presentation/paywall_screen.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_purchase_store.dart';
import '../fakes/fake_settings_store.dart';

void main() {
  final l = lookupAppLocalizations(kFallbackLocale);
  testWidgets(
    '[LIC-02/AC1] paywall displays store prices and handles pending, cancellation, purchase and restore',
    (t) async {
      final clock = FakeClock();
      final store = FakePurchaseStore();
      final entitlement = LocalEntitlementService(
        clock: clock,
        mode: DistributionMode.commercial,
      );
      final service = PurchaseService(
        store: store,
        settings: FakeSettingsStore(),
        entitlements: entitlement,
        clock: clock,
      );
      addTearDown(() async {
        await service.dispose();
        await entitlement.dispose();
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseServiceProvider.overrideWithValue(service),
            storeProductsProvider.overrideWith((ref) async => store.catalog),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PaywallScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l.purchaseAnnual('STORE ANNUAL')), findsOneWidget);
      expect(find.text(l.purchaseLifetime('STORE LIFETIME')), findsOneWidget);
      for (final outcome in [
        PurchaseOutcome.pending,
        PurchaseOutcome.cancelled,
        PurchaseOutcome.purchased,
      ]) {
        store
          ..outcome = Ok(outcome)
          ..owned = const Ok([StoreOwnership(lifetimeProductId)]);
        await t.tap(find.text(l.purchaseLifetime('STORE LIFETIME')));
        await t.pumpAndSettle();
        expect(
          find.text(switch (outcome) {
            PurchaseOutcome.pending => l.purchasePending,
            PurchaseOutcome.cancelled => l.purchaseCancelled,
            PurchaseOutcome.purchased => l.purchaseComplete,
          }),
          findsOneWidget,
        );
      }
      await t.ensureVisible(find.text(l.purchaseRestore));
      await t.tap(find.text(l.purchaseRestore));
      await t.pumpAndSettle();
      expect(store.restores, 1);
      expect(find.text(l.purchaseRestored), findsOneWidget);
    },
  );

  testWidgets(
    '[LIC-02/AC1] loading, unavailable and retry states are visible',
    (t) async {
      final ready = Completer<List<StoreProduct>>();
      var calls = 0;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            storeProductsProvider.overrideWith((ref) {
              calls++;
              return ready.future;
            }),
          ],
          child: const MaterialApp(home: PaywallScreen()),
        ),
      );
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ready.complete(const []);
      await t.pumpAndSettle();
      expect(find.text(l.purchaseUnavailable), findsOneWidget);
      await t.tap(find.text(l.purchaseRetry));
      await t.pumpAndSettle();
      expect(calls, 2);
    },
  );
}
