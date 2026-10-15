import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/security/sqlite3mc_cipher.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';

void main() {
  Future<void> pump(WidgetTester t, DatabaseCipher cipher) => t.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
        vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
        routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
        databaseCipherProvider.overrideWithValue(cipher),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );

  Future<void> show(WidgetTester t) async {
    final tile = find.byKey(const ValueKey('privacy-encryption'));
    await t.scrollUntilVisible(tile, 200);
    await t.pumpAndSettle();
  }

  testWidgets('[SEC-01] Settings reports the encrypted database and explains '
      'that vault exports are plaintext', (t) async {
    await pump(t, Sqlite3mcCipher(Uint8List(32), hardwareBacked: true));
    await t.pumpAndSettle();
    await show(t);
    expect(find.textContaining('the database is encrypted'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('privacy-encryption')));
    await t.pumpAndSettle();
    expect(find.textContaining('plain Markdown files'), findsOneWidget);
    expect(find.textContaining('file encryption'), findsOneWidget);
  });

  testWidgets('[SEC-01] Settings reports an unavailable key', (t) async {
    await pump(t, const UnavailableCipher());
    await t.pumpAndSettle();
    await show(t);
    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });
}
