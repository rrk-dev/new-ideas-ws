import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/network_activity_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';

void main() {
  testWidgets('[SEC-02] Settings → Network activity lists every request and '
      'offline mode is a privacy toggle stored as network_disabled', (t) async {
    final log = NetworkActivityLog()
      ..record(
        NetworkActivityEntry.request(
          DateTime.utc(2026, 10, 14, 9),
          Uri.parse('https://huggingface.co/x/model.bin'),
          NetworkOutcome.completed,
          statusCode: 200,
          bytes: 1234,
        ),
      )
      ..record(
        NetworkActivityEntry.request(
          DateTime.utc(2026, 10, 14, 9, 1),
          Uri.parse('https://evil.example/leak'),
          NetworkOutcome.denied,
        ),
      );
    final store = FakeSettingsStore();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          networkActivityLogProvider.overrideWithValue(log),
          settingsStoreProvider.overrideWithValue(store),
          vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
          routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    final offline = find.text('Offline mode');
    await t.scrollUntilVisible(offline, 200);
    await t.ensureVisible(offline);
    await t.pumpAndSettle();
    await t.tap(offline);
    await t.pumpAndSettle();
    expect(store.values[SettingKeys.networkOffline], isTrue);

    final tile = find.byKey(const ValueKey('privacy-network-activity'));
    await t.scrollUntilVisible(tile, 200);
    await t.ensureVisible(tile);
    await t.pumpAndSettle();
    await t.tap(tile);
    await t.pumpAndSettle();
    expect(find.byType(NetworkActivityScreen), findsOneWidget);
    expect(find.text('huggingface.co/x/model.bin'), findsOneWidget);
    expect(find.textContaining('HTTP 200'), findsOneWidget);
    expect(find.textContaining('1234 bytes'), findsOneWidget);
    expect(find.text('evil.example/leak'), findsOneWidget);
    expect(find.textContaining('Blocked before sending'), findsOneWidget);
    // Newest first.
    final first = t.getTopLeft(find.text('evil.example/leak'));
    final second = t.getTopLeft(find.text('huggingface.co/x/model.bin'));
    expect(first.dy, lessThan(second.dy));

    await t.tap(find.byKey(const ValueKey('network-activity-clear')));
    await t.pumpAndSettle();
    expect(find.text('No network requests yet.'), findsOneWidget);
  });
}
