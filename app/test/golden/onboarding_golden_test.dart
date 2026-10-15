import 'package:vaultvoice/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/golden.dart';

void main() {
  goldenTest(
    '[APP-01] Onboarding (privacy explainer)',
    fileName: 'onboarding_privacy',
    overrides: [
      settingsStoreProvider.overrideWith((ref) => FakeSettingsStore()),
    ],
    builder: (_) => const OnboardingScreen(),
  );
}
