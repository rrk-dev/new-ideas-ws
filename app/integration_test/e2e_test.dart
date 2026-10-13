import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';

/// Directory holding the files from `tools/ci/fetch_test_models.sh`, already
/// copied onto the device (`--dart-define=VV_TEST_MODELS_DIR=<device path>`).
const String kTestModelsDir = String.fromEnvironment('VV_TEST_MODELS_DIR');

/// On-device end-to-end suite (docs/testing.md → "On-device integration").
/// Run on a physical device or simulator:
///   cd app && fvm flutter test integration_test/e2e_test.dart \
///     --flavor dev -d DEVICE_ID [--dart-define=VV_TEST_MODELS_DIR=...]
/// Device rows: docs/test-plans/device/QA-01.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots into the tab shell on device', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Record'), findsWidgets);
  });

  // Minimum flow from vv-testing. Enabled once the real engines and the
  // debug-only model seeding hook exist (QA-01 follow-ups). Steps:
  //  1. seed ggml-tiny.en.bin + the test GGUF from kTestModelsDir;
  //  2. import jfk.wav → pipeline runs → transcript contains "country";
  //  3. Meeting profile extraction → schema-valid JSON;
  //  4. export to the app-local vault → file exists, front-matter parses.
  testWidgets(
    'record → transcribe → extract → export with tiny models',
    skip: true,
    (tester) async {
      expect(kTestModelsDir, isNotEmpty, reason: 'pass VV_TEST_MODELS_DIR');
    },
  );
}
