import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/models/presentation/models_screen.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_call_guard.dart';
import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_recording_indicator.dart';
import '../fakes/fake_settings_store.dart';
import '../helpers/golden.dart';
import '../helpers/library_fixtures.dart';
import '../helpers/model_fixtures.dart';

ModelEntry _entry(CatalogModel m, {bool installed = false}) => ModelEntry(
  model: m,
  installed: installed
      ? InstalledModel(
          id: m.id,
          version: m.version,
          size: m.size,
          relativePath: 'models/${m.id}/${m.file}',
          installedAt: DateTime.utc(2026),
        )
      : null,
  access: AccessLevel.full,
  compatible: true,
  recommended: installed,
  active: installed,
);

final _cases = <String, ({Widget screen, List<Override> overrides})>{
  'Onboarding': (
    screen: const OnboardingScreen(),
    overrides: [settingsStoreProvider.overrideWith((r) => FakeSettingsStore())],
  ),
  'Record': (
    screen: const RecordScreen(),
    overrides: [
      captureBackendProvider.overrideWithValue(FakeCaptureBackend()),
      callGuardProvider.overrideWithValue(FakeCallGuard()),
      recordingIndicatorProvider.overrideWithValue(FakeRecordingIndicator()),
      profileChoicesProvider.overrideWith((ref) => Stream.value(const [])),
      destinationChoicesProvider.overrideWith((ref) async => const []),
      recoveredRecordingsProvider.overrideWith((ref) async => const []),
      batteryStatusProvider.overrideWith((ref) async => null),
      settingsStoreProvider.overrideWithValue(
        FakeSettingsStore({OnboardingKeys.micPrimed: true}),
      ),
    ],
  ),
  'Library': (screen: const LibraryScreen(), overrides: libraryOverrides()),
  'Settings': (
    screen: const SettingsScreen(),
    overrides: [
      settingsStoreProvider.overrideWith((ref) => FakeSettingsStore()),
      vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
      routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  ),
  'Models': (
    screen: const ModelsScreen(),
    overrides: [
      settingsStoreProvider.overrideWith((ref) => FakeSettingsStore()),
      modelEntriesProvider.overrideWith(
        (ref) async => [_entry(seedStt, installed: true), _entry(seedLlm)],
      ),
      storageUsageProvider.overrideWith(
        (ref) => Stream.value(
          const StorageUsage(modelBytes: 1, audioBytes: 2, transcriptBytes: 3),
        ),
      ),
      modelDownloadProgressProvider.overrideWith(
        (ref) => Stream.value(const {}),
      ),
      networkDisabledProvider.overrideWith((ref) => Stream.value(false)),
    ],
  ),
};

void main() {
  for (final MapEntry(key: name, value: c) in _cases.entries) {
    for (final theme in GoldenTheme.values) {
      testWidgets(
        '[APP-08/AC3] $name renders at text scale 2.0 without overflow '
        '(${theme.name})',
        (t) async {
          t.view
            ..physicalSize = kGoldenSurface
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            ProviderScope(
              overrides: c.overrides,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: theme.data,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: c.screen,
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            await t.drag(scrollables.first, const Offset(0, -3000));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
        },
      );
    }
  }
}
