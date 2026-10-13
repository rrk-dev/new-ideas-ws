import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden.dart';

/// Runs once per test file under `test/` (flutter_test convention): loads
/// real fonts and installs the tolerant golden comparator. See
/// docs/testing.md → "Golden tests".
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadTestFonts();
  useTolerantGoldenComparator();
  await testMain();
}
