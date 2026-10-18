import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden.dart';

/// Runs once per test file under `test/` (flutter_test convention): loads
/// real fonts and installs the tolerant golden comparator. See
/// docs/testing.md → "Golden tests".
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadTestFonts();
  useTolerantGoldenComparator();
  // LIC-04: no MDM configuration unless a test overrides the source.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('vaultvoice/managed_config'),
        (_) async => null,
      );
  await testMain();
}
