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
      'iOS 16.4+',
      'ARMv8.2-A + dotprod',
      'API 26+',
      'arm64-v8a',
      'lefthook install',
    ]) {
      expect(doc, contains(needle));
    }
  });

  // Product owner decision 2026-10-14: iOS 16.4 minimum (ADR-FND-06 §4).
  test('iOS 16.4 minimum is pinned in Xcode, the podspec and build.sh', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final targets = RegExp('IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);')
        .allMatches(pbx)
        .map((m) => m.group(1))
        .toList();
    expect(targets, isNotEmpty);
    expect(targets.toSet(), {'16.4'});
    expect(
      File('../packages/vv_native/ios/vv_native.podspec').readAsStringSync(),
      contains("s.platform = :ios, '16.4'"),
    );
    expect(
      File('../native/build.sh').readAsStringSync(),
      contains(r'IOS_MIN_OS="${IOS_MIN_OS:-16.4}"'),
    );
  });
}
