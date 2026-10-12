import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/app_info.dart';

void main() {
  final analysis = File('analysis_options.yaml').readAsStringSync();

  test('[FND-01/AC1] analysis enforces strict lints, no print, no dynamic', () {
    expect(analysis, contains('package:very_good_analysis/'));
    expect(analysis, contains('avoid_print: error'));
    expect(analysis, contains('avoid_dynamic_calls: error'));
    expect(analysis, contains('strict-casts: true'));
  });

  test('[FND-01/AC1] product name is a single constant', () {
    expect(kAppName, 'VaultVoice');
  });

  test('[FND-01/AC3] CONTRIBUTING documents layout, flavors and targets', () {
    final doc = File('../CONTRIBUTING.md').readAsStringSync();
    for (final needle in [
      '## Folder layout',
      'lib/features/<feature>/',
      '--flavor dev',
      'iOS 16.0+',
      'API 26+',
      'arm64-v8a',
      'lefthook install',
    ]) {
      expect(doc, contains(needle));
    }
  });
}
