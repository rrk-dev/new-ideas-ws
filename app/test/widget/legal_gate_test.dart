import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/presentation/ask_panel.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/legal/presentation/legal_gate.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_settings_store.dart';

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

Future<void> _pumpGate(WidgetTester t, FakeSettingsStore store) => t.pumpWidget(
  ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10, 18))),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LegalGate(child: Scaffold(body: Text('the app'))),
    ),
  ),
);

void main() {
  testWidgets('[LEG-01/AC2] the app stays covered until the user ticks both '
      'boxes and taps agree; the choice is stored with version and time', (
    t,
  ) async {
    final store = FakeSettingsStore();
    await _pumpGate(t, store);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-gate')), findsOneWidget);
    expect(find.text('the app'), findsNothing);

    FilledButton button() =>
        t.widget<FilledButton>(find.byKey(const ValueKey('legal-accept')));
    expect(button().onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('legal-age')));
    await t.pump();
    expect(button().onPressed, isNull, reason: 'age alone is not enough');
    await t.tap(find.byKey(const ValueKey('legal-agree')));
    await t.pump();
    expect(button().onPressed, isNotNull);
    expect(store.values[LegalKeys.acceptedVersion], isNull);

    await t.tap(find.byKey(const ValueKey('legal-accept')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-gate')), findsNothing);
    expect(find.text('the app'), findsOneWidget);
    expect(store.values[LegalKeys.acceptedVersion], kLegalVersion);
    expect(store.values[LegalKeys.ageConfirmed], true);
    expect(
      store.values[LegalKeys.acceptedAt],
      DateTime.utc(2026, 10, 18).millisecondsSinceEpoch,
    );
  });

  testWidgets('[LEG-01/AC2] both documents can be read from the gate '
      'without leaving it', (t) async {
    await _pumpGate(t, FakeSettingsStore());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('legal-read-terms')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-terms')), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('legal-read-privacy')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-privacy')), findsOneWidget);
  });

  testWidgets('[LEG-01/AC3] an accepted current version does not prompt', (
    t,
  ) async {
    await _pumpGate(
      t,
      FakeSettingsStore({LegalKeys.acceptedVersion: kLegalVersion}),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-gate')), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('[LEG-01/AC3] a different bundled version prompts again', (
    t,
  ) async {
    await _pumpGate(
      t,
      FakeSettingsStore({LegalKeys.acceptedVersion: '2000-01-01'}),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-gate')), findsOneWidget);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('[LEG-01/AC5] Ask answers carry the AI-output disclaimer', (
    t,
  ) async {
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AskAnswerCard(
              answer: AskAnswer(outcome: AskOutcome.answered, answer: 'May.'),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('ask-disclaimer')), findsOneWidget);
    expect(find.text(_l.aiOutputDisclaimer), findsOneWidget);
  });
}
