import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';

import '../fakes/fake_clock.dart';

class _RecordingPaywall implements PaywallPresenter {
  final requests = <PaywallRequest>[];
  void Function()? onShow;

  @override
  Future<void> show(PaywallRequest request) async {
    requests.add(request);
    onShow?.call();
  }
}

void main() {
  final t0 = DateTime.utc(2026, 3);

  Future<WidgetRef> pump(
    WidgetTester tester, {
    required DistributionMode mode,
    required PaywallPresenter paywall,
  }) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(t0)),
          distributionModeProvider.overrideWithValue(mode),
          paywallPresenterProvider.overrideWithValue(paywall),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return FeatureGate(
                feature: Feature.customTemplates,
                enabled: (_) => const Text('editor'),
                locked: (_) => const Text('locked'),
              );
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('commercial Free: gate locked, ensureFeature opens paywall', (
    tester,
  ) async {
    final paywall = _RecordingPaywall();
    final ref = await pump(
      tester,
      mode: DistributionMode.commercial,
      paywall: paywall,
    );
    expect(find.text('locked'), findsOneWidget);

    expect(
      await ensureFeature(
        ref,
        Feature.customTemplates,
        from: PaywallEntryPoint.templateEditor,
      ),
      isFalse,
    );
    expect(paywall.requests.single.feature, Feature.customTemplates);
    expect(
      paywall.requests.single.entryPoint,
      PaywallEntryPoint.templateEditor,
    );

    // A purchase during the paywall unlocks the feature.
    paywall.onShow = () => ref
        .read(entitlementServiceProvider)
        .update(
          Entitlement(
            plan: Plan.proLifetime,
            verifiedAt: t0,
            source: EntitlementSource.appStore,
          ),
        );
    expect(
      await ensureFeature(
        ref,
        Feature.customTemplates,
        from: PaywallEntryPoint.templateEditor,
      ),
      isTrue,
    );
    await tester.pump();
    expect(find.text('editor'), findsOneWidget);
  });

  testWidgets('personal build: unlocked, managed feature never paywalls', (
    tester,
  ) async {
    final paywall = _RecordingPaywall();
    final ref = await pump(
      tester,
      mode: DistributionMode.personal,
      paywall: paywall,
    );
    expect(find.text('editor'), findsOneWidget);
    expect(
      await ensureFeature(
        ref,
        Feature.managedProfiles,
        from: PaywallEntryPoint.settings,
      ),
      isFalse,
    );
    expect(paywall.requests, isEmpty);
  });
}
