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
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/app_lock/domain/app_lock.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_gate.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/network_activity_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/processing_fixtures.dart';

class _Managed implements ManagedSettingsSource {
  const _Managed();

  @override
  Stream<ManagedSettings> watch() =>
      Stream.value(const ManagedSettings(values: {'security.app_lock': true}));
}

/// The routes below are audited unlocked (the managed settings above force
/// the app lock on, so the lock is opened here); the lock screen (SEC-03)
/// has its own rows at the end.
class _Unlocked extends AppLock {
  @override
  AppLockView build() => const AppLockView(enabled: false, locked: false);
}

class _NoAuth implements DeviceAuthenticator {
  @override
  Future<AuthOutcome> authenticate(String reason) async => AuthOutcome.failed;
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
};

List<Override> _overrides({bool locked = false}) => [
  if (!locked) appLockProvider.overrideWith(_Unlocked.new),
  deviceAuthenticatorProvider.overrideWithValue(_NoAuth()),
  flavorProvider.overrideWithValue(Flavor.prod),
  processingViewsProvider.overrideWith((ref) async => sampleQueue()),
  // Hermetic: no platform storage dir (path_provider) behind the
  // recording/model providers that joined in integration wave 2.
  storagePathsProvider.overrideWith((ref) => Completer<StoragePaths>().future),
  settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
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
  bool locked = false,
}) async {
  final container = ProviderContainer(overrides: _overrides(locked: locked));
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

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('[APP-06/AC1] App lock screen (${mode.name}): labelled '
        'controls, tap targets and WCAG AA text contrast', (t) async {
      final handle = t.ensureSemantics();
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await _pumpAt(t, '/settings', mode: mode, scale: 1, locked: true);
      expect(find.byType(LockScreen), findsOneWidget);
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('[APP-06/AC1] App lock screen renders at 200 % text size '
      'without overflow', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await _pumpAt(
      t,
      '/settings',
      mode: ThemeMode.light,
      scale: 2,
      locked: true,
    );
    expect(find.byType(LockScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('[APP-06/AC1] Network activity (${mode.name}, '
          '${(scale * 100).round()} %): labelled controls, tap targets, '
          'contrast, no overflow', (t) async {
        final handle = t.ensureSemantics();
        t.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final log = NetworkActivityLog()
          ..record(
            NetworkActivityEntry.request(
              DateTime.utc(2026, 10, 14, 9),
              Uri.parse('https://huggingface.co/ggerganov/model.bin'),
              NetworkOutcome.completed,
              statusCode: 200,
              bytes: 77000000,
            ),
          );
        await t.pumpWidget(
          ProviderScope(
            overrides: [networkActivityLogProvider.overrideWithValue(log)],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const NetworkActivityScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (scale == 1) {
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
        }
        handle.dispose();
      });
    }
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
