import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_readiness_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_readiness.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/profiles/presentation/profiles_screen.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/library_fixtures.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        flavorProvider.overrideWithValue(Flavor.dev),
        // Hermetic: no database behind the processing-queue indicator.
        processingViewsProvider.overrideWith((ref) async => const []),
        // APP-01: past onboarding, so the router does not redirect.
        settingsStoreProvider.overrideWithValue(
          FakeSettingsStore({
            OnboardingKeys.completed: true,
            LegalKeys.acceptedVersion: kLegalVersion,
          }),
        ),
        onboardingReadinessProvider.overrideWith(
          (ref) async => OnboardingReadiness.allReady,
        ),
        vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
        routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
        // Integration W3: AUD-08's Record screen pickers (DB streams).
        profileChoicesProvider.overrideWith((ref) => Stream.value(const [])),
        destinationChoicesProvider.overrideWith((ref) async => const []),
        // APP-02: the Library tab lists recordings.
        ...libraryOverrides(),
      ],
      child: const App(),
    ),
  );

  testWidgets('[FND-02/AC1] boots into the tab shell on Record', (t) async {
    await pumpApp(t);
    await t.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Record', 'Library', 'Profiles', 'Settings']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(RecordScreen), findsOneWidget);
  });

  testWidgets('[FND-02/AC1] each tab shows its placeholder screen', (t) async {
    await pumpApp(t);
    await t.pumpAndSettle();

    final screens = <String, Type>{
      'Library': LibraryScreen,
      'Profiles': ProfilesScreen,
      'Settings': SettingsScreen,
      'Record': RecordScreen,
    };
    for (final MapEntry(key: label, value: type) in screens.entries) {
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(type), findsOneWidget);
    }
  });
}
