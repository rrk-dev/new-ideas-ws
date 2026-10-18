import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

import '../../fakes/fake_clock.dart';
import '../../helpers/test_container.dart';

void main() {
  final t0 = DateTime.utc(2026, 3);
  const commercial = DistributionMode.commercial;

  Entitlement pro({DateTime? expiresAt, Plan plan = Plan.proAnnual}) =>
      Entitlement(
        plan: plan,
        verifiedAt: t0,
        source: EntitlementSource.appStore,
        expiresAt: expiresAt,
      );

  group('entitlement expiry', () {
    test('[LIC-01/AC1] annual Pro is Pro before expiry and Free after', () {
      final e = pro(expiresAt: t0.add(const Duration(days: 365)));
      expect(e.effectivePlanAt(t0), Plan.proAnnual);
      expect(
        e.effectivePlanAt(t0.add(const Duration(days: 364))),
        Plan.proAnnual,
      );
      expect(e.effectivePlanAt(t0.add(const Duration(days: 365))), Plan.free);
    });

    test('[LIC-01/AC1] annual Pro without expiry fails closed to Free', () {
      expect(pro().effectivePlanAt(t0), Plan.free);
    });

    test('[LIC-01/AC1] lifetime Pro never expires', () {
      final e = pro(plan: Plan.proLifetime);
      expect(
        e.effectivePlanAt(t0.add(const Duration(days: 365 * 50))),
        Plan.proLifetime,
      );
      expect(e.nextChangeAfter(t0), isNull);
    });

    test('[LIC-01/AC1] enterprise licence expires; extras dropped', () {
      final e = Entitlement(
        plan: Plan.enterprise,
        verifiedAt: t0,
        source: EntitlementSource.enterpriseLicense,
        expiresAt: t0.add(const Duration(days: 10)),
        extraFeatures: const {Feature.managedProfiles},
      );
      final before = FeatureAccess.resolve(e, now: t0, mode: commercial);
      expect(before.has(Feature.managedProfiles), isTrue);
      final after = FeatureAccess.resolve(
        e,
        now: t0.add(const Duration(days: 10)),
        mode: commercial,
      );
      expect(after.effectivePlan, Plan.free);
      expect(after.has(Feature.managedProfiles), isFalse);
      expect(after.isDowngraded, isTrue);
    });
  });

  group('downgrade keeps user content', () {
    final expired = FeatureAccess.resolve(
      pro(expiresAt: t0),
      now: t0.add(const Duration(days: 1)),
      mode: commercial,
    );

    test('[LIC-01/AC1] expired Pro: custom profiles/templates/rules '
        'become read-only (not hidden, not deleted)', () {
      expect(expired.isDowngraded, isTrue);
      expect(expired.customProfiles, AccessLevel.readOnly);
      expect(expired.customTemplates, AccessLevel.readOnly);
      expect(expired.routingRules, AccessLevel.readOnly);
      expect(expired.has(Feature.customProfiles), isFalse);
    });

    test('[LIC-01/AC1] expired Pro: first vault target stays, extra '
        'targets disabled', () {
      expect(expired.vaultTarget(0), AccessLevel.full);
      expect(expired.vaultTarget(1), AccessLevel.disabled);
      expect(expired.vaultTarget(5), AccessLevel.disabled);
    });

    test('[LIC-01/AC1] expired Pro: installed Pro models stay installed '
        'but cannot be selected', () {
      expect(
        expired.model(ModelTier.pro, installed: true),
        AccessLevel.readOnly,
      );
      expect(
        expired.model(ModelTier.pro, installed: false),
        AccessLevel.disabled,
      );
      expect(expired.model(ModelTier.free, installed: true), AccessLevel.full);
      expect(expired.has(Feature.highAccuracyStt), isFalse);
      expect(expired.has(Feature.largeLlm), isFalse);
    });

    test('[LIC-01/AC1] personal build: expiry changes nothing visible', () {
      final a = FeatureAccess.resolve(
        pro(expiresAt: t0),
        now: t0.add(const Duration(days: 1)),
        mode: DistributionMode.personal,
      );
      expect(a.customProfiles, AccessLevel.full);
      expect(a.vaultTarget(3), AccessLevel.full);
      expect(a.model(ModelTier.pro, installed: true), AccessLevel.full);
    });
  });

  group('LocalEntitlementService', () {
    test('[LIC-01/AC1] emits a downgrade when the subscription expires', () {
      fakeAsync((async) {
        final clock = FakeClock(t0);
        final service = LocalEntitlementService(
          clock: clock,
          mode: commercial,
          initial: pro(expiresAt: t0.add(const Duration(hours: 1))),
        );
        final seen = <Plan>[];
        service.changes.listen((a) => seen.add(a.effectivePlan));
        expect(service.has(Feature.customProfiles), isTrue);

        clock.advance(const Duration(minutes: 59));
        async.elapse(const Duration(minutes: 59));
        expect(seen, isEmpty);

        clock.advance(const Duration(minutes: 2));
        async.elapse(const Duration(minutes: 2));
        expect(seen, [Plan.free]);
        expect(service.has(Feature.customProfiles), isFalse);
        expect(service.access.customProfiles, AccessLevel.readOnly);
        unawaited(service.dispose());
      });
    });

    test(
      '[LIC-01/AC1] update() upgrades; identical update is silent',
      () async {
        final service = LocalEntitlementService(
          clock: FakeClock(t0),
          mode: commercial,
        );
        addTearDown(service.dispose);
        final seen = <Plan>[];
        service.changes.listen((a) => seen.add(a.effectivePlan));
        expect(service.has(Feature.largeLlm), isFalse);
        final lifetime = pro(plan: Plan.proLifetime);
        service
          ..update(lifetime)
          ..update(lifetime);
        await Future<void>.delayed(Duration.zero);
        expect(seen, [Plan.proLifetime]);
        expect(service.has(Feature.largeLlm), isTrue);
      },
    );

    test('[LIC-01/AC1] refresh() catches a clock jump past expiry', () async {
      final clock = FakeClock(t0);
      final service = LocalEntitlementService(
        clock: clock,
        mode: commercial,
        initial: pro(expiresAt: t0.add(const Duration(days: 1))),
      );
      addTearDown(service.dispose);
      clock.advance(const Duration(days: 2));
      service.refresh();
      expect(service.access.effectivePlan, Plan.free);
    });
  });

  group('providers', () {
    test('[LIC-01/AC1] featureProvider follows entitlement changes', () async {
      final clock = FakeClock(t0);
      final c = createContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          distributionModeProvider.overrideWithValue(commercial),
          proTierEnforcedProvider.overrideWithValue(true),
        ],
      );
      final sub = c.listen(featureProvider(Feature.multiTarget), (_, _) {});
      addTearDown(sub.close);
      expect(sub.read(), isFalse);

      c
          .read(entitlementServiceProvider)
          .update(pro(expiresAt: t0.add(const Duration(days: 30))));
      await Future<void>.delayed(Duration.zero);
      expect(sub.read(), isTrue);
      expect(c.read(entitlementSummaryProvider).plan, Plan.proAnnual);
      expect(c.read(entitlementSummaryProvider).isDowngraded, isFalse);

      clock.advance(const Duration(days: 31));
      (c.read(entitlementServiceProvider) as LocalEntitlementService).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(sub.read(), isFalse);
      final summary = c.read(entitlementSummaryProvider);
      expect(summary.effectivePlan, Plan.free);
      expect(summary.isDowngraded, isTrue);
      expect(
        c.read(modelAccessProvider(ModelTier.pro, installed: true)),
        AccessLevel.readOnly,
      );
    });

    test('default distribution mode is personal: Free has Pro features', () {
      final c = createContainer(
        overrides: [clockProvider.overrideWithValue(FakeClock(t0))],
      );
      expect(c.read(distributionModeProvider), DistributionMode.personal);
      expect(c.read(featureProvider(Feature.customProfiles)), isTrue);
      expect(c.read(featureProvider(Feature.managedProfiles)), isFalse);
      expect(c.read(entitlementSummaryProvider).plan, Plan.free);
    });
  });
}
