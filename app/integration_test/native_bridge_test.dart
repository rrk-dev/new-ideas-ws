import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vv_native/vv_native.dart';

/// On-device check that the bundled native bridge loads and answers.
/// Run: `fvm flutter test integration_test/native_bridge_test.dart
///   --flavor dev -d DEVICE_ID` (Android arm64 + iPhone, iOS 16+).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('[FND-06/AC2] vv_version() answers on device', (tester) async {
    final native = VvNative.open();
    expect(native.version, '0.1.0');
    expect(native.abiVersion, expectedAbiVersion);
    expect(native.whisperVersion, isNotEmpty);
    expect(native.llamaSystemInfo, isNotEmpty);
  });
}
