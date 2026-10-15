import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/review/presentation/schema_form.dart';

void main() {
  testWidgets('[APP-05] invalid numeric input is flagged, not coerced to 0', (
    t,
  ) async {
    var value = <String, Object?>{'cost': 5};
    final validity = <bool>[];
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SchemaForm(
              schema: const ObjectSchema(
                properties: {'cost': NumberSchema(integer: false)},
              ),
              value: value,
              onChanged: (v) => setState(() => value = v),
              onInputValidityChanged: validity.add,
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const ValueKey('field-0-cost'));
    await t.enterText(field, '-');
    await t.pump();
    expect(validity.last, isFalse);
    expect(value['cost'], 5, reason: 'not silently replaced by 0');
    expect(
      find.text(lookupAppLocalizations(kFallbackLocale).reviewNumberInvalid),
      findsOneWidget,
    );
    await t.enterText(field, '7.5');
    await t.pump();
    expect(validity.last, isTrue);
    expect(value['cost'], 7.5);
  });
}
