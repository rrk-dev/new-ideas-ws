import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/setting_texts.dart';
import 'package:vaultvoice/features/settings/presentation/setting_tiles.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/settings_values.dart';

class _Managed implements ManagedSettingsSource {
  _Managed(this.settings);

  final ManagedSettings settings;

  @override
  Stream<ManagedSettings> watch() => Stream.value(settings);
}

class _License implements LicenseSettingsPort {
  int restores = 0;
  final installed = <String>[];

  @override
  Stream<LicenseSummary> watch() => Stream.value(
    LicenseSummary(
      tier: LicenseTier.enterprise,
      organization: 'Acme',
      expiresAt: DateTime(2027, 3, 31, 12),
    ),
  );

  @override
  Future<Result<void>> restorePurchases() async {
    restores++;
    return const Ok(null);
  }

  @override
  Future<Result<void>> installEnterpriseLicense(String license) async {
    installed.add(license);
    return const Ok(null);
  }
}

class _Wiper implements DataWiper {
  int calls = 0;

  @override
  Future<Result<void>> deleteAllData() async {
    calls++;
    return const Ok(null);
  }
}

final AppLocalizations en = lookupAppLocalizations(kFallbackLocale);

void main() {
  late FakeSettingsStore store;

  setUp(() => store = FakeSettingsStore());

  Future<void> pump(WidgetTester t, {List<Override> overrides = const []}) =>
      t.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            vaultTargetsProvider.overrideWith(
              (ref) => Stream.value(const [
                VaultTargetInfo(
                  id: 'v1',
                  name: 'Notes',
                  platform: VaultPlatform.appLocal,
                  handle: '/x',
                ),
              ]),
            ),
            routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
            ...overrides,
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

  /// Scrolls the settings list from the top until [f] is visible.
  Future<void> show(WidgetTester t, Finder f) async {
    final list = find.byType(Scrollable).first;
    await t.drag(list, const Offset(0, 100000));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(f, 200, scrollable: list);
    await t.pumpAndSettle();
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  Future<Object?> stored(WidgetTester t, String key) async => store.values[key];

  Future<void> edit(WidgetTester t, SettingDef<Object> def, Object v) async {
    await t.tap(find.byKey(settingTileKey(def.key)));
    await t.pumpAndSettle();
    switch (def) {
      case ToggleSetting():
        break;
      case ChoiceSetting():
        await t.tap(find.byKey(ValueKey('option-$v')));
      case TextSetting():
        await t.enterText(
          find.byKey(const ValueKey('setting-text-field')),
          '$v',
        );
        await t.tap(find.text('Save'));
    }
    await t.pumpAndSettle();
  }

  testWidgets('[APP-03/AC1] every setting is editable and persisted in the '
      'settings table', (t) async {
    await pump(t);
    await t.pumpAndSettle();
    for (final def in AppSettings.all) {
      final tile = find.byKey(settingTileKey(def.key));
      await show(t, tile);
      expect(tile, findsOneWidget, reason: def.key);
      final v = otherValue(def);
      await edit(t, def, v);
      expect(await stored(t, def.key), v, reason: def.key);
    }
    // The stored values are what a fresh screen shows (persistence).
    await t.pumpWidget(const SizedBox());
    await pump(t);
    await t.pumpAndSettle();
    const pattern = AppSettings.filenamePattern;
    await show(t, find.byKey(settingTileKey(pattern.key)));
    expect(find.text('{{date:YYYY}}/{{slug}}.md'), findsOneWidget);
  });

  testWidgets('[APP-03/AC1] managed (enterprise-locked) settings are shown '
      'read-only with the managed value', (t) async {
    await store.set(AppSettings.chargeOnly.key, false);
    final managed = ManagedSettings(
      values: {
        for (final d in AppSettings.all)
          if (d != AppSettings.chargeOnly) d.key: otherValue(d),
      },
      locked: {AppSettings.chargeOnly.key},
    );
    await pump(
      t,
      overrides: [
        managedSettingsSourceProvider.overrideWithValue(_Managed(managed)),
      ],
    );
    await t.pumpAndSettle();
    for (final def in AppSettings.all) {
      final tile = find.byKey(settingTileKey(def.key));
      await show(t, tile);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
        reason: def.key,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining(en.settingManaged),
        ),
        findsOneWidget,
      );
      if (def case ToggleSetting()) {
        final sw = t.widget<SwitchListTile>(tile);
        expect(sw.onChanged, isNull, reason: def.key);
        expect(
          sw.value,
          def == AppSettings.chargeOnly ? false : otherValue(def),
        );
      } else {
        expect(t.widget<ListTile>(tile).enabled, isFalse, reason: def.key);
      }
      await t.tap(tile, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing, reason: def.key);
    }
    // Nothing was written over the user's own stored values.
    for (final def in AppSettings.all) {
      if (def == AppSettings.chargeOnly) continue;
      expect(await stored(t, def.key), isNull, reason: def.key);
    }
    expect(await stored(t, AppSettings.chargeOnly.key), false);
  });

  test('writer refuses managed keys and invalid values', () async {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        managedSettingsSourceProvider.overrideWithValue(
          _Managed(ManagedSettings(locked: {AppSettings.appLock.key})),
        ),
      ],
    );
    addTearDown(container.dispose);
    final w = container.read(settingsWriterProvider);
    expect((await w.set(AppSettings.appLock, true)).isOk, isFalse);
    expect((await w.set(AppSettings.collisionMode, 'nope')).isOk, isFalse);
    expect(
      (await w.set(AppSettings.filenamePattern, '../escape.md')).isOk,
      isFalse,
    );
    expect((await w.set(AppSettings.collisionMode, 'skip')).isOk, isTrue);
    expect(store.values, {AppSettings.collisionMode.key: 'skip'});
  });

  testWidgets('filename pattern dialog validates input', (t) async {
    await pump(t);
    await t.pumpAndSettle();
    final tile = find.byKey(settingTileKey(AppSettings.filenamePattern.key));
    await show(t, tile);
    await t.tap(tile);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('setting-text-field')), '');
    await t.tap(find.text('Save'));
    await t.pump();
    expect(find.text('Enter a pattern.'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('setting-text-field')),
      '{{date:YYYY',
    );
    await t.tap(find.text('Save'));
    await t.pump();
    expect(find.text('Every {{ needs a matching }}.'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(await stored(t, AppSettings.filenamePattern.key), isNull);
  });

  testWidgets('sections, links, license, encryption, delete all and about', (
    t,
  ) async {
    final license = _License();
    final wiper = _Wiper();
    await pump(
      t,
      overrides: [
        licenseSettingsPortProvider.overrideWithValue(license),
        dataWiperProvider.overrideWithValue(wiper),
      ],
    );
    await t.pumpAndSettle();
    for (final s in SettingSection.values) {
      await show(t, find.text(SettingTexts.section(en, s)));
    }
    await show(t, find.byKey(const ValueKey('link-vault-folders')));
    expect(find.text('1 folder'), findsOneWidget);
    await show(t, find.byKey(const ValueKey('link-models')));
    expect(find.text('Models'), findsOneWidget);

    await show(t, find.byKey(const ValueKey('privacy-encryption')));
    expect(
      find.text('Off — this build does not encrypt the database.'),
      findsOneWidget,
    );

    await show(t, find.byKey(const ValueKey('privacy-delete-all')));
    await t.tap(find.byKey(const ValueKey('privacy-delete-all')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete everything'));
    await t.pumpAndSettle();
    expect(find.text('All data deleted.'), findsOneWidget);
    expect(wiper.calls, 1);

    await show(t, find.byKey(const ValueKey('license-status')));
    expect(find.text('Enterprise · Acme · until 2027-03-31'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('license-restore')));
    await t.pumpAndSettle();
    expect(license.restores, 1);
    await t.tap(find.byKey(const ValueKey('license-enterprise')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('license-text-field')), 'L1');
    await t.tap(find.text('Install'));
    await t.pumpAndSettle();
    expect(license.installed, ['L1']);

    // Snack bars would cover the last tiles.
    t
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await t.pumpAndSettle();
    await show(t, find.byKey(const ValueKey('about-version')));
    expect(find.text('$kAppName $kAppVersion'), findsOneWidget);
    await show(t, find.byKey(const ValueKey('about-privacy-policy')));
    await t.tap(find.byKey(const ValueKey('about-privacy-policy')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('privacy-policy-text')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await show(t, find.byKey(const ValueKey('about-licenses')));
    await t.tap(find.byKey(const ValueKey('about-licenses')));
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  group('vault folders and routing rules screens', () {
    Future<void> pumpSub(
      WidgetTester t,
      Widget screen, {
      required Stream<List<VaultTargetInfo>> targets,
      Stream<List<RoutingRuleInfo>>? rules,
    }) => t.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          vaultTargetsProvider.overrideWith((ref) => targets),
          routingRulesProvider.overrideWith(
            (ref) => rules ?? Stream.value(const []),
          ),
          // EXP-05: the rules screen lists full rules (editable).
          routingRuleListProvider.overrideWith(
            (ref) => (rules ?? Stream.value(const <RoutingRuleInfo>[])).map(
              (list) => [
                for (final (i, r) in list.indexed)
                  RoutingRule(
                    id: r.id,
                    priority: i,
                    targetId: r.targetId,
                    subPath: r.subPath,
                  ),
              ],
            ),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );

    const notes = VaultTargetInfo(
      id: 'v1',
      name: 'Notes',
      platform: VaultPlatform.appLocal,
      handle: '/x',
    );

    testWidgets('vault folders: empty, list, error', (t) async {
      await pumpSub(t, const VaultFoldersScreen(), targets: Stream.value([]));
      await t.pumpAndSettle();
      expect(find.textContaining('No vault folders yet'), findsOneWidget);
      expect(find.text('Add folder'), findsOneWidget);
      await pumpSub(
        t,
        const VaultFoldersScreen(),
        targets: Stream.value([notes]),
      );
      await t.pumpAndSettle();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.byTooltip('Remove Notes'), findsOneWidget);
      await pumpSub(
        t,
        const VaultFoldersScreen(),
        targets: Stream.error(StateError('db')),
      );
      await t.pumpAndSettle();
      expect(find.text('Could not load your vault folders.'), findsOneWidget);
    });

    testWidgets('routing rules: empty and ordered list', (t) async {
      await pumpSub(t, const RoutingRulesScreen(), targets: Stream.value([]));
      await t.pumpAndSettle();
      expect(find.textContaining('No routing rules'), findsOneWidget);
      await pumpSub(
        t,
        const RoutingRulesScreen(),
        targets: Stream.value([notes]),
        rules: Stream.value(const [
          RoutingRuleInfo(id: 'r1', targetId: 'v1', subPath: 'Meetings'),
        ]),
      );
      await t.pumpAndSettle();
      expect(find.text('To Notes'), findsOneWidget);
      expect(find.text('Every note · Meetings'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
