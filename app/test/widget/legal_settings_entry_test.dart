import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';

void main() {
  testWidgets('[LEG-01/AC4] Settings → About opens the bundled Terms of use '
      'and the Privacy policy', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
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
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await t.pumpAndSettle();

    Future<void> open(String key) async {
      final f = find.byKey(ValueKey(key));
      final list = find.byType(Scrollable).first;
      await t.scrollUntilVisible(f, 200, scrollable: list);
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    await open('about-terms-of-use');
    expect(find.byKey(const ValueKey('terms-of-use-text')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await open('about-privacy-policy');
    expect(find.byKey(const ValueKey('privacy-policy-text')), findsOneWidget);
  });
}
