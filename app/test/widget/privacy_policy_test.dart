import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/gen/app_localizations.dart';
import 'package:vaultvoice/features/settings/presentation/privacy_policy_screen.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.text);

  final String? text;

  @override
  Future<ByteData> load(String key) async {
    if (text == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text!)));
  }
}

Future<void> _pump(WidgetTester t, AssetBundle bundle) => t.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PrivacyPolicyScreen(bundle: bundle),
  ),
);

void main() {
  testWidgets('[SEC-06/AC1] the policy screen renders the bundled text', (
    t,
  ) async {
    await _pump(t, _Bundle('# Policy\n\nNo data is collected.'));
    await t.pumpAndSettle();
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('No data is collected.'), findsOneWidget);
  });

  testWidgets('[SEC-06/AC1] a missing asset shows a message, not a crash', (
    t,
  ) async {
    await _pump(t, _Bundle(null));
    await t.pumpAndSettle();
    expect(find.text('The privacy policy could not be shown.'), findsOneWidget);
  });

  test(
    '[SEC-06/AC1] the shipped asset exists and says no data is collected',
    () {
      final text = File(PrivacyPolicyScreen.assetPath).readAsStringSync();
      expect(text, contains('No data is collected'));
    },
  );
}
