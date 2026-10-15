import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../test/fakes/fake_settings_store.dart';
import '../test/helpers/store_demo_data.dart';

/// Store screenshot capture (REL-05). Synthetic demo data only.
///
///   cd app && fvm flutter test integration_test/store_screenshots_test.dart \
///     --flavor prod --dart-define=VV_STORE_SCREENSHOTS=true
///
/// Host machines without a simulator should not run this file.
const bool kCaptureStoreScreenshots = bool.fromEnvironment(
  'VV_STORE_SCREENSHOTS',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '[REL-05/AC1] store screenshot routes render synthetic demo data',
    (tester) async {
      for (final (name, location) in kStoreScreenshotShots) {
        final onboarded = location != '/onboarding';
        final container = ProviderContainer(
          overrides: [
            flavorProvider.overrideWithValue(Flavor.prod),
            settingsStoreProvider.overrideWithValue(
              FakeSettingsStore({
                if (onboarded) OnboardingKeys.completed: true,
              }),
            ),
            onboardingRequiredProvider.overrideWith(
              (ref) => Stream.value(!onboarded),
            ),
            processingViewsProvider.overrideWith((ref) async => const []),
            ...storeDemoOverrides(),
          ],
        );
        addTearDown(container.dispose);
        container.read(appRouterProvider).go(location);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const App()),
        );
        await tester.pumpAndSettle();

        if (location == '/library') {
          expect(find.text(kStoreDemoTitle), findsOneWidget);
        }
        if (location.endsWith('/text')) {
          expect(find.textContaining(kStoreDemoSpeakerA), findsWidgets);
          expect(find.text('Priya'), findsNothing);
        }

        if (kCaptureStoreScreenshots) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pump();
          await binding.takeScreenshot(name);
        }
      }
    },
  );
}
