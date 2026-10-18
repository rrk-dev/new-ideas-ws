import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

import '../../fakes/fake_clock.dart';

/// The intended future tier of each Phase 2 feature
/// (free, pro, enterprise, personal).
const _phase2 = <Feature, (bool, bool, bool, bool)>{
  Feature.quickCapture: (true, true, true, true),
  Feature.lectureProfile: (false, true, true, true),
  Feature.salesProfile: (false, true, true, true),
  Feature.interviewProfile: (false, true, true, true),
  Feature.askNotes: (false, true, true, true),
  Feature.mindMap: (false, true, true, true),
  Feature.remindersExport: (false, true, true, true),
};

void main() {
  final now = DateTime.utc(2026, 6);

  test('[LIC-05/AC1] every Phase 2 feature has a matrix row; every cell', () {
    for (final e in _phase2.entries) {
      final row = kFeatureMatrix[e.key]!;
      final (free, pro, ent, personal) = e.value;
      expect(row.free, free, reason: '${e.key.name}.free');
      expect(row.pro, pro, reason: '${e.key.name}.pro');
      expect(row.enterprise, ent, reason: '${e.key.name}.enterprise');
      expect(row.personal, personal, reason: '${e.key.name}.personal');
    }
    // The 3B model follows the size rule: Feature.largeLlm stays Pro.
    expect(kFeatureMatrix[Feature.largeLlm]!.free, isFalse);
    expect(kFeatureMatrix[Feature.largeLlm]!.pro, isTrue);
  });

  test('[LIC-05/AC3] switch off: Free has every Pro-column feature', () {
    for (final f in Feature.values) {
      expect(
        featureEnabled(
          f,
          Plan.free,
          DistributionMode.commercial,
          proTierEnforced: false,
        ),
        f != Feature.managedProfiles,
        reason: f.name,
      );
    }
    expect(
      maxModelTier(
        Plan.free,
        DistributionMode.commercial,
        proTierEnforced: false,
      ),
      ModelTier.pro,
    );
    final svc = LocalEntitlementService(
      clock: FakeClock(now),
      mode: DistributionMode.commercial,
      proTierEnforced: false,
    );
    addTearDown(svc.dispose);
    expect(svc.has(Feature.askNotes), isTrue);
    expect(svc.has(Feature.largeLlm), isTrue);
    expect(svc.access.paywallEnabled, isFalse);
    // Organisation management still needs an enterprise licence.
    expect(svc.has(Feature.managedProfiles), isFalse);
  });

  test('[LIC-05/AC4] switch on: Free is gated, Pro and Enterprise open', () {
    final svc = LocalEntitlementService(
      clock: FakeClock(now),
      mode: DistributionMode.commercial,
    );
    addTearDown(svc.dispose);
    expect(svc.proTierEnforced, isTrue);
    for (final e in _phase2.entries) {
      expect(svc.has(e.key), e.value.$1, reason: e.key.name);
    }
    expect(svc.has(Feature.largeLlm), isFalse);
    expect(svc.access.paywallEnabled, isTrue);
    expect(
      maxModelTier(Plan.free, DistributionMode.commercial),
      ModelTier.free,
    );
    for (final plan in [Plan.proAnnual, Plan.proLifetime, Plan.enterprise]) {
      for (final f in _phase2.keys) {
        expect(
          featureEnabled(f, plan, DistributionMode.commercial),
          isTrue,
          reason: '${plan.name} ${f.name}',
        );
      }
    }
  });

  test('[LIC-05/AC5] personal builds unlock everything but organisation '
      'management, with the switch on or off', () {
    for (final enforced in [true, false]) {
      for (final f in Feature.values) {
        expect(
          featureEnabled(
            f,
            Plan.free,
            DistributionMode.personal,
            proTierEnforced: enforced,
          ),
          f != Feature.managedProfiles,
          reason: '${f.name} enforced=$enforced',
        );
      }
    }
  });

  test('the shipped default is "no Pro tier enforced"', () {
    expect(kProTierEnforced, isFalse);
  });
}
