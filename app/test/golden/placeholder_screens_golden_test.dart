import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_call_guard.dart';
import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_recording_indicator.dart';
import '../fakes/fake_settings_store.dart';
import '../helpers/golden.dart';
import '../helpers/library_fixtures.dart';

void main() {
  goldenTest(
    'Record screen',
    fileName: 'record_screen',
    builder: (_) => const RecordScreen(),
    // Hermetic: fake capture/call guard, no profiles or vault folders yet.
    overrides: [
      captureBackendProvider.overrideWithValue(FakeCaptureBackend()),
      callGuardProvider.overrideWithValue(FakeCallGuard()),
      recordingIndicatorProvider.overrideWithValue(FakeRecordingIndicator()),
      profileChoicesProvider.overrideWith((ref) => Stream.value(const [])),
      destinationChoicesProvider.overrideWith((ref) async => const []),
      recoveredRecordingsProvider.overrideWith((ref) async => const []),
      batteryStatusProvider.overrideWith((ref) async => null),
      // APP-01 mic priming state, read up front (integration W3).
      settingsStoreProvider.overrideWithValue(
        FakeSettingsStore({OnboardingKeys.micPrimed: true}),
      ),
    ],
  );
  // APP-02: the real Library (was a placeholder until then).
  goldenTest(
    '[APP-02] Library screen',
    fileName: 'library_screen',
    overrides: libraryOverrides(),
    builder: (_) => const LibraryScreen(),
  );
}
