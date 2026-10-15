import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Project settings for the macOS runner. Does not build or launch the app.
void main() {
  final appDir = Directory.current;
  final macos = File('macos/Runner.xcodeproj/project.pbxproj')
      .readAsStringSync();
  final info = File('macos/Runner/Info.plist').readAsStringSync();
  final window = File('macos/Runner/MainFlutterWindow.swift')
      .readAsStringSync();
  final menu = File('macos/Runner/Base.lproj/MainMenu.xib').readAsStringSync();
  final devScheme = File(
    'macos/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme',
  ).readAsStringSync();
  final prodScheme = File(
    'macos/Runner.xcodeproj/xcshareddata/xcschemes/prod.xcscheme',
  ).readAsStringSync();

  test('[FND-09/AC1] macOS dev flavor is an arm64 app, minimum macOS 13', () {
    expect(Directory('macos').existsSync(), isTrue);
    expect(Directory('web').existsSync(), isFalse);
    expect(Directory('linux').existsSync(), isFalse);
    expect(Directory('windows').existsSync(), isFalse);

    final metadata = File('.metadata').readAsStringSync();
    expect(metadata, contains('platform: android'));
    expect(metadata, contains('platform: ios'));
    expect(metadata, contains('platform: macos'));

    expect(macos, isNot(contains('name = Debug;')));
    expect(macos, isNot(contains('name = Release;')));
    expect(macos, isNot(contains('name = Profile;')));
    expect(macos, isNot(contains('MACOSX_DEPLOYMENT_TARGET = 12.0;')));

    final configs = _configurations(macos);
    final appConfigs = configs
        .where((c) => c.body.contains('INFOPLIST_FILE = Runner/Info.plist;'))
        .toList();
    expect(appConfigs.map((c) => c.name).toSet(), {
      'Debug-dev',
      'Debug-prod',
      'Release-dev',
      'Release-prod',
      'Profile-dev',
      'Profile-prod',
    });

    for (final config in configs.where(
      (c) =>
          c.body.contains('SDKROOT = macosx;') ||
          c.body.contains('INFOPLIST_FILE = Runner/Info.plist;'),
    )) {
      expect(
        config.body,
        contains('MACOSX_DEPLOYMENT_TARGET = 13.0;'),
        reason: config.name,
      );
      expect(config.body, contains('ARCHS = arm64;'), reason: config.name);
      expect(
        config.body,
        contains('EXCLUDED_ARCHS = x86_64;'),
        reason: config.name,
      );
      expect(
        config.body,
        isNot(contains('ARCHS = arm64 x86_64')),
        reason: config.name,
      );
    }

    for (final config in appConfigs) {
      final dev = config.name.endsWith('-dev');
      expect(
        config.body,
        contains(
          dev
              ? 'PRODUCT_BUNDLE_IDENTIFIER = com.vaultvoice.vaultvoice.dev;'
              : 'PRODUCT_BUNDLE_IDENTIFIER = com.vaultvoice.vaultvoice;',
        ),
        reason: config.name,
      );
      expect(
        config.body,
        contains(
          dev
              ? 'APP_DISPLAY_NAME = "VaultVoice Dev";'
              : 'APP_DISPLAY_NAME = VaultVoice;',
        ),
        reason: config.name,
      );
    }

    expect(info, contains('<key>CFBundleDisplayName</key>'));
    expect(info, contains(r'<string>$(APP_DISPLAY_NAME)</string>'));
    expect(info, contains(r'<string>$(MACOSX_DEPLOYMENT_TARGET)</string>'));

    expect(devScheme, contains('buildConfiguration = "Debug-dev"'));
    expect(devScheme, contains('buildConfiguration = "Release-dev"'));
    expect(devScheme, contains('buildConfiguration = "Profile-dev"'));
    expect(prodScheme, contains('buildConfiguration = "Debug-prod"'));
    expect(prodScheme, contains('buildConfiguration = "Release-prod"'));
    expect(
      File('macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme')
          .existsSync(),
      isFalse,
    );

    expect(
      window,
      contains('contentMinSize = NSSize(width: 800, height: 600)'),
    );
    expect(window, contains('.closable'));
    expect(window, contains('.miniaturizable'));
    expect(window, contains('.resizable'));
    expect(
      menu,
      contains(
        'windowStyleMask key="styleMask" titled="YES" closable="YES" '
        'miniaturizable="YES" resizable="YES"',
      ),
    );
    expect(menu, contains('performMiniaturize:'));
    expect(menu, contains('performZoom:'));

    for (final name in [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      final entitlements = File(name).readAsStringSync();
      expect(entitlements, contains('device.audio-input'));
      expect(entitlements, isNot(contains('device.camera')));
      expect(entitlements, isNot(contains('screen-capture')));
    }

    // iOS and Android projects stay on their existing targets.
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(ios, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
    expect(ios, contains('com.vaultvoice.vaultvoice.dev'));
    expect(ios, contains('com.vaultvoice.vaultvoice'));
    expect(ios, isNot(contains('MACOSX_DEPLOYMENT_TARGET')));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('minSdk = 26'));
    expect(gradle, contains('arm64-v8a'));

    final contributing = File('${appDir.path}/../CONTRIBUTING.md')
        .readAsStringSync();
    expect(contributing, contains('macOS 13+ arm64'));
    expect(contributing, contains('Web, Linux, and Windows are out of scope.'));
    final agents = File('../AGENTS.md').readAsStringSync();
    expect(
      agents,
      contains('iOS 16+, Android API 26+ (arm64-v8a only), macOS 13+ arm64.'),
    );
  });
}

final class _Config {
  _Config(this.name, this.body);

  final String name;
  final String body;
}

List<_Config> _configurations(String pbxproj) {
  final re = RegExp(
    r'isa = XCBuildConfiguration;\n(.*?)name = "?([A-Za-z0-9-]+)"?;',
    dotAll: true,
  );
  return [
    for (final match in re.allMatches(pbxproj))
      _Config(match.group(2)!, match.group(1)!),
  ];
}
