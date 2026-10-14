import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/model_fixtures.dart';
import '../helpers/processing_fixtures.dart';

class _Managed implements ManagedSettingsSource {
  const _Managed();

  @override
  Stream<ManagedSettings> watch() =>
      Stream.value(const ManagedSettings(values: {'security.app_lock': true}));
}

/// Every screen reachable in the app today, by route location.
const _screens = {
  'Record': '/record',
  'Library': '/library',
  'Processing queue': '/library/processing',
  'Recording status': '/library/recordings/rec-a',
  'Profiles': '/profiles',
  'Settings': '/settings',
  'Vault folders': '/settings/vault-folders',
  'Routing rules': '/settings/routing-rules',
  'Models': '/settings/models',
  'Onboarding': '/onboarding',
};

List<Override> _overrides() => [
  flavorProvider.overrideWithValue(Flavor.prod),
  processingViewsProvider.overrideWith((ref) async => sampleQueue()),
  // Hermetic: no platform storage dir (path_provider) behind the
  // recording/model providers that joined in integration wave 2.
  storagePathsProvider.overrideWith((ref) => Completer<StoragePaths>().future),
  // APP-01: past onboarding, so the router does not redirect.
  settingsStoreProvider.overrideWithValue(
    FakeSettingsStore({OnboardingKeys.completed: true}),
  ),
  managedSettingsSourceProvider.overrideWithValue(const _Managed()),
  vaultTargetsProvider.overrideWith(
    (ref) => Stream.value(const [
      VaultTargetInfo(
        id: 'v1',
        name: 'Obsidian vault',
        platform: VaultPlatform.appLocal,
        handle: '/x',
      ),
    ]),
  ),
  // MDL-03 model screen: hermetic catalog/install state.
  modelEntriesProvider.overrideWith(
    (ref) async => [
      ModelEntry(
        model: seedStt,
        installed: InstalledModel(
          id: seedStt.id,
          version: '1',
          size: seedStt.size,
          relativePath: 'models/x/y.bin',
          installedAt: DateTime.utc(2026),
        ),
        access: AccessLevel.full,
        compatible: true,
        recommended: true,
        active: true,
      ),
      ModelEntry(
        model: seedLlm,
        installed: null,
        access: AccessLevel.full,
        compatible: true,
        recommended: true,
        active: false,
      ),
    ],
  ),
  storageUsageProvider.overrideWith(
    (ref) => Stream.value(
      const StorageUsage(modelBytes: 1, audioBytes: 2, transcriptBytes: 3),
    ),
  ),
  modelDownloadProgressProvider.overrideWith((ref) => Stream.value(const {})),
  networkDisabledProvider.overrideWith((ref) => Stream.value(false)),
  routingRulesProvider.overrideWith(
    (ref) => Stream.value(const [
      RoutingRuleInfo(id: 'r1', targetId: 'v1', subPath: 'Meetings'),
    ]),
  ),
];

Future<void> _pumpAt(
  WidgetTester t,
  String location, {
  required ThemeMode mode,
  required double scale,
}) async {
  final container = ProviderContainer(overrides: _overrides());
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(location);
  t.platformDispatcher
    ..platformBrightnessTestValue = mode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light
    ..textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await t.pumpAndSettle();
  // The variant really applies, and the route really rendered.
  final ctx = t.element(find.byType(Scaffold).last);
  expect(
    Theme.of(ctx).brightness,
    mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
  );
  expect(MediaQuery.textScalerOf(ctx).scale(10), 10 * scale);
  expect(
    container.read(appRouterProvider).routeInformationProvider.value.uri.path,
    location,
  );
}

void main() {
  for (final MapEntry(key: name, value: location) in _screens.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('[APP-06/AC1] $name (${mode.name}): labelled controls, '
          'tap targets and WCAG AA text contrast', (t) async {
        final handle = t.ensureSemantics();
        t.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await _pumpAt(t, location, mode: mode, scale: 1);
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
    testWidgets('[APP-06/AC1] $name renders at 200 % text size without '
        'overflow', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await _pumpAt(t, location, mode: ThemeMode.light, scale: 2);
      expect(t.takeException(), isNull);
      // Scroll through scrollable content: nothing overflows further down.
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await t.drag(scrollables.first, const Offset(0, -3000));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    });
  }

  testWidgets('[APP-06/AC1] tab bar and queue indicator announce their '
      'purpose to screen readers', (t) async {
    final handle = t.ensureSemantics();
    await _pumpAt(t, '/record', mode: ThemeMode.light, scale: 1);
    final l = lookupAppLocalizations(kFallbackLocale);
    for (final label in [
      l.tabRecord,
      l.tabLibrary,
      l.tabProfiles,
      l.tabSettings,
    ]) {
      expect(find.bySemanticsLabel(RegExp(label)), findsWidgets);
    }
    expect(
      find.bySemanticsLabel(
        RegExp('Processing 3 recordings · 1 needs attention. Open processing'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('theme colour pairs used for status text meet WCAG AA (4.5:1)', () {
    double luminance(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final s = theme.colorScheme;
      for (final (fg, bg) in [
        (s.onSurface, s.surface),
        (s.onSurfaceVariant, s.surface),
        (s.primary, s.surface),
        (s.error, s.surface),
        (s.onSecondaryContainer, s.secondaryContainer),
        (s.onError, s.error),
      ]) {
        expect(ratio(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
      }
    }
  });
}
