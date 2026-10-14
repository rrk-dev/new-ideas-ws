import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Expected commercial matrix, written out independently of
/// `kFeatureMatrix` so a changed cell fails a test (master plan §7 +
/// the PRODUCT-DECISION defaults documented in LIC-01).
///                                  (free,  pro,   enterprise)
const _commercial = <Feature, (bool, bool, bool)>{
  Feature.smallStt: (false, true, true),
  Feature.highAccuracyStt: (false, true, true),
  Feature.largeLlm: (false, true, true),
  Feature.customTemplates: (false, true, true),
  Feature.customProfiles: (false, true, true),
  Feature.multiTarget: (false, true, true),
  Feature.routingRules: (false, true, true),
  Feature.builtinWarranty: (false, true, true),
  Feature.builtinEngineering: (false, true, true),
  Feature.managedProfiles: (false, false, true),
  Feature.sideloadCustomModel: (false, true, true),
};

/// Personal build: everything on, except managed profiles which need an
/// enterprise licence.
bool _personal(Feature f, Plan p) =>
    f != Feature.managedProfiles || p == Plan.enterprise;

bool _expectedCommercial(Feature f, Plan p) {
  final (free, pro, ent) = _commercial[f]!;
  return switch (p) {
    Plan.free => free,
    Plan.proAnnual || Plan.proLifetime => pro,
    Plan.enterprise => ent,
  };
}

void main() {
  final now = DateTime.utc(2026, 6);
  final later = now.add(const Duration(days: 30));

  Entitlement active(Plan p) => Entitlement(
    plan: p,
    verifiedAt: now,
    source: EntitlementSource.builtIn,
    expiresAt: later,
  );

  test('[LIC-01/AC1] the matrix has exactly one row per Feature', () {
    expect(kFeatureMatrix.keys.toSet(), Feature.values.toSet());
    expect(_commercial.keys.toSet(), Feature.values.toSet());
  });

  for (final mode in DistributionMode.values) {
    group('${mode.name} build', () {
      for (final feature in Feature.values) {
        for (final plan in Plan.values) {
          final expected = mode == DistributionMode.commercial
              ? _expectedCommercial(feature, plan)
              : _personal(feature, plan);
          test('[LIC-01/AC1] ${feature.name} × ${plan.name} '
              '(${mode.name}) = $expected', () {
            expect(featureEnabled(feature, plan, mode), expected);
            final access = FeatureAccess.resolve(
              active(plan),
              now: now,
              mode: mode,
            );
            expect(access.effectivePlan, plan);
            expect(access.has(feature), expected);
          });
        }
      }
    });
  }

  group('model tiers', () {
    const expected = {
      (Plan.free, DistributionMode.commercial): ModelTier.free,
      (Plan.proAnnual, DistributionMode.commercial): ModelTier.pro,
      (Plan.proLifetime, DistributionMode.commercial): ModelTier.pro,
      (Plan.enterprise, DistributionMode.commercial): ModelTier.enterprise,
      (Plan.free, DistributionMode.personal): ModelTier.pro,
      (Plan.proAnnual, DistributionMode.personal): ModelTier.pro,
      (Plan.proLifetime, DistributionMode.personal): ModelTier.pro,
      (Plan.enterprise, DistributionMode.personal): ModelTier.enterprise,
    };
    for (final MapEntry(key: (plan, mode), value: tier) in expected.entries) {
      test('[LIC-01/AC1] max model tier ${plan.name} (${mode.name}) = '
          '${tier.name}', () {
        expect(maxModelTier(plan, mode), tier);
        final access = FeatureAccess.resolve(
          active(plan),
          now: now,
          mode: mode,
        );
        for (final t in ModelTier.values) {
          expect(
            access.model(t, installed: false),
            t.index <= tier.index ? AccessLevel.full : AccessLevel.disabled,
            reason: t.name,
          );
        }
      });
    }
  });

  group('limits per tier (commercial)', () {
    for (final plan in Plan.values) {
      final paid = plan != Plan.free;
      test(
        '[LIC-01/AC1] ${plan.name}: targets, profiles, templates, rules',
        () {
          final a = FeatureAccess.resolve(
            active(plan),
            now: now,
            mode: DistributionMode.commercial,
          );
          expect(a.maxActiveVaultTargets, paid ? null : 1);
          expect(a.vaultTarget(0), AccessLevel.full);
          expect(
            a.vaultTarget(1),
            paid ? AccessLevel.full : AccessLevel.disabled,
          );
          final level = paid ? AccessLevel.full : AccessLevel.readOnly;
          expect(a.customProfiles, level);
          expect(a.customTemplates, level);
          expect(a.routingRules, level);
          expect(a.paywallEnabled, isTrue);
        },
      );
    }
  });

  test('[LIC-01/AC1] personal build never shows a paywall', () {
    for (final plan in Plan.values) {
      final a = FeatureAccess.resolve(
        active(plan),
        now: now,
        mode: DistributionMode.personal,
      );
      expect(a.paywallEnabled, isFalse);
      expect(a.maxActiveVaultTargets, isNull);
    }
  });

  test('default build is personal (VV_COMMERCIAL unset)', () {
    expect(kCommercialBuild, isFalse);
  });
}
