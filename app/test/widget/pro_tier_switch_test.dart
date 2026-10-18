import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/mindmap/data/mind_map_providers.dart';
import 'package:vaultvoice/features/mindmap/presentation/mind_map_tab.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/profiles/domain/profile_features.dart';

import '../fakes/fake_clock.dart';

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

class _Paywall implements PaywallPresenter {
  final requests = <PaywallRequest>[];

  @override
  Future<void> show(PaywallRequest request) async => requests.add(request);
}

/// Every Phase 2 entry point, as the feature it asks the matrix about.
final _entryPoints = <String, Feature>{
  'ask': Feature.askNotes,
  'mind map': Feature.mindMap,
  'reminders export': Feature.remindersExport,
  'lecture profile': featureForProfile('lecture')!,
  'sales profile': featureForProfile('sales_call')!,
  'interview profile': featureForProfile('interview')!,
  '3B model': Feature.largeLlm,
};

Future<({WidgetRef ref, _Paywall paywall, ProviderContainer container})>
_pumpGate(WidgetTester t, {required bool enforced}) async {
  final paywall = _Paywall();
  late WidgetRef captured;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 3))),
        distributionModeProvider.overrideWithValue(DistributionMode.commercial),
        proTierEnforcedProvider.overrideWithValue(enforced),
        paywallPresenterProvider.overrideWithValue(paywall),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return (
    ref: captured,
    paywall: paywall,
    container: ProviderScope.containerOf(t.element(find.byType(Consumer))),
  );
}

Future<void> _pumpMindMapTab(
  WidgetTester t, {
  required bool enforced,
  required _Paywall paywall,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = VaultVoiceDatabase(NativeDatabase.memory());
  addTearDown(() => t.runAsync(db.close));
  final overrides = <Override>[
    clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 3))),
    distributionModeProvider.overrideWithValue(DistributionMode.commercial),
    proTierEnforcedProvider.overrideWithValue(enforced),
    paywallPresenterProvider.overrideWithValue(paywall),
    vaultVoiceDatabaseProvider.overrideWithValue(db),
    recordingMindMapProvider('rec-a').overrideWith((ref) => Stream.value(null)),
    mindMapRequestedProvider('rec-a')
        .overrideWith((ref) => Stream.value(false)),
    recordingTranscriptProvider('rec-a').overrideWith(
      (ref) => Stream.value(const [
        TranscriptLine(startMs: 0, endMs: 1000, text: 'Hello'),
      ]),
    ),
    processingViewsProvider.overrideWith((ref) async => []),
  ];
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MindMapTab(recordingId: 'rec-a')),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    '[LIC-05/AC3] switch off: Ask, mind maps, Reminders export, the new '
    'profiles and the 3B model are open on Free, no paywall',
    (t) async {
      final rig = await _pumpGate(t, enforced: false);
      for (final e in _entryPoints.entries) {
        expect(rig.ref.read(featureProvider(e.value)), isTrue, reason: e.key);
        expect(
          await ensureFeature(
            rig.ref,
            e.value,
            from: PaywallEntryPoint.settings,
          ),
          isTrue,
          reason: e.key,
        );
      }
      expect(
        rig.ref
            .read(featureAccessStateProvider)
            .model(ModelTier.pro, installed: false),
        AccessLevel.full,
      );
      expect(rig.paywall.requests, isEmpty);
    },
  );

  testWidgets('[LIC-05/AC3] switch off: the mind map tab is open on Free', (
    t,
  ) async {
    final paywall = _Paywall();
    await _pumpMindMapTab(t, enforced: false, paywall: paywall);
    expect(find.text(_l.mindMapNone), findsOneWidget);
    expect(find.text(_l.mindMapLocked), findsNothing);
    expect(paywall.requests, isEmpty);
  });

  testWidgets(
    '[LIC-05/AC4] switch on: the same entry points paywall Free and open for Pro',
    (t) async {
      final rig = await _pumpGate(t, enforced: true);
      for (final e in _entryPoints.entries) {
        expect(rig.ref.read(featureProvider(e.value)), isFalse, reason: e.key);
        expect(
          await ensureFeature(
            rig.ref,
            e.value,
            from: PaywallEntryPoint.settings,
          ),
          isFalse,
          reason: e.key,
        );
      }
      expect(rig.paywall.requests.map((r) => r.feature), [
        for (final e in _entryPoints.entries) e.value,
      ]);
      expect(
        rig.ref
            .read(featureAccessStateProvider)
            .model(ModelTier.pro, installed: false),
        AccessLevel.disabled,
      );

      rig.container
          .read(entitlementServiceProvider)
          .update(
            Entitlement(
              plan: Plan.proLifetime,
              verifiedAt: DateTime.utc(2026, 3),
              source: EntitlementSource.appStore,
            ),
          );
      await t.pump();
      for (final e in _entryPoints.entries) {
        expect(rig.ref.read(featureProvider(e.value)), isTrue, reason: e.key);
      }
    },
  );

  testWidgets('[LIC-05/AC4] switch on: the mind map tab shows the paywall', (
    t,
  ) async {
    final paywall = _Paywall();
    await _pumpMindMapTab(t, enforced: true, paywall: paywall);
    expect(find.text(_l.mindMapLocked), findsOneWidget);
    await t.tap(find.text(_l.paywallTitle));
    await t.pump();
    expect(paywall.requests.single.feature, Feature.mindMap);
    expect(paywall.requests.single.entryPoint, PaywallEntryPoint.mindMap);
  });
}
