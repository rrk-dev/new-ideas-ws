import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/data/entitlement_license_port.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/domain/custom_model_entitlement.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

import '../../fakes/fake_clock.dart';

// Integration wave 2: LLM-07's plan gate and MDL-04's custom-model
// entitlement are backed by LIC-01's EntitlementService (no placeholders).
void main() {
  final t0 = DateTime.utc(2026, 3);

  LocalEntitlementService service(DistributionMode mode, {Plan? plan}) =>
      LocalEntitlementService(
        clock: FakeClock(t0),
        mode: mode,
        initial: plan == null
            ? null
            : Entitlement(
                plan: plan,
                verifiedAt: t0,
                source: EntitlementSource.appStore,
              ),
      );

  test('LlmPlanGate.entitlements follows Feature.largeLlm', () {
    final free = service(DistributionMode.commercial);
    final pro = service(DistributionMode.commercial, plan: Plan.proLifetime);
    final personal = service(DistributionMode.personal);
    expect(LlmPlanGate.entitlements(free).largeLlm(), isFalse);
    expect(LlmPlanGate.entitlements(pro).largeLlm(), isTrue);
    expect(
      LlmPlanGate.entitlements(personal).largeLlm(),
      featureEnabled(Feature.largeLlm, Plan.free, DistributionMode.personal),
    );
  });

  test('EntitlementCustomModels follows Feature.sideloadCustomModel', () async {
    expect(
      await EntitlementCustomModels(service(DistributionMode.commercial))
          .allowsCustomModels(),
      isFalse,
    );
    expect(
      await EntitlementCustomModels(
        service(DistributionMode.commercial, plan: Plan.proLifetime),
      ).allowsCustomModels(),
      isTrue,
    );
  });

  test('customModelEntitlementProvider is the LIC-01 check', () async {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(t0)),
        distributionModeProvider.overrideWithValue(DistributionMode.commercial),
      ],
    );
    addTearDown(c.dispose);
    final e = c.read(customModelEntitlementProvider);
    expect(e, isA<EntitlementCustomModels>());
    expect(await e.allowsCustomModels(), isFalse);
    c
        .read(entitlementServiceProvider)
        .update(
          Entitlement(
            plan: Plan.proLifetime,
            verifiedAt: t0,
            source: EntitlementSource.appStore,
          ),
        );
    expect(await e.allowsCustomModels(), isTrue);
  });

  test('Settings license hook shows the effective LIC-01 plan', () async {
    final svc = service(DistributionMode.commercial);
    final port = EntitlementLicensePort(svc);
    final seen = <LicenseTier>[];
    final sub = port.watch().listen((s) => seen.add(s.tier));
    await Future<void>.delayed(Duration.zero);
    svc.update(
      Entitlement(
        plan: Plan.proLifetime,
        verifiedAt: t0,
        source: EntitlementSource.appStore,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [LicenseTier.free, LicenseTier.pro]);
    expect((await port.restorePurchases()).isOk, isFalse);
  });
}
