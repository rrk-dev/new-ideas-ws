import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/branding/lumen_logo.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/security/key_vault.dart';
import 'package:vaultvoice/features/profiles/domain/profile_bundle.dart';

/// Identifiers that legitimately keep the old name (APP-07): Dart class names,
/// wire/network identifiers and release-infrastructure names that must not
/// change, so installs and data survive the rename.
final _allowedOldName = RegExp(
  'VaultVoice(Database|/| Dart error report| native crash report| External)',
);

List<File> _files(String dir, {required bool Function(String) where}) {
  final root = Directory(dir);
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => where(f.path))
      .toList();
}

bool _isNonEmptyPng(File f) {
  if (!f.existsSync()) return false;
  final b = f.readAsBytesSync();
  return b.length > 100 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
}

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const ios = 'ios/Runner/Assets.xcassets';
  const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  const res = 'android/app/src/main/res';

  group('[APP-07/AC1] no user-visible VaultVoice', () {
    test('[APP-07/AC1] app/lib, ARBs, manifests, store docs and docs', () {
      bool text(String path) =>
          !path.contains('/adr/') &&
          !path.contains('/build/') &&
          !path.contains('/Pods/') &&
          !path.contains('/Flutter/') &&
          RegExp(
            r'\.(dart|arb|plist|xml|kts|md|txt|mustache|json|swift|kt|'
            r'storyboard|xcprivacy)$',
          ).hasMatch(path);

      final files = <File>[
        ..._files('lib', where: text),
        ..._files('assets', where: text),
        ..._files('ios/Runner', where: text),
        ..._files('ios/ShareExtension', where: text),
        ..._files('ios/fastlane', where: text),
        ..._files('macos/Runner', where: text),
        ..._files('android/app/src/main', where: text),
        ..._files('android/fastlane', where: text),
        ..._files('../docs', where: text),
        File('../packages/vv_native/macos/Info.plist'),
        File('android/app/build.gradle.kts'),
        File('ios/Runner.xcodeproj/project.pbxproj'),
        File('macos/Runner.xcodeproj/project.pbxproj'),
      ];
      expect(files.length, greaterThan(40));

      final offenders = <String>[];
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final stripped = lines[i].replaceAll(_allowedOldName, '');
          if (stripped.contains('VaultVoice')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('[APP-07/AC1] display names are Lumen / Lumen Dev', () {
      expect(kAppName, 'Lumen');
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('"app_name", "Lumen Dev"'));
      expect(gradle, contains('"app_name", "Lumen")'));
      final iosProj = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(iosProj, contains('APP_DISPLAY_NAME = "Lumen Dev";'));
      // Xcode rewrites the value unquoted when it has no space.
      expect(iosProj, contains('APP_DISPLAY_NAME = Lumen;'));
      final macProj = File('macos/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(macProj, contains('APP_DISPLAY_NAME = Lumen;'));
      expect(macProj, contains('APP_DISPLAY_NAME = "Lumen Dev";'));
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains(r'$(APP_DISPLAY_NAME)'),
      );
    });
  });

  group('[APP-07/AC2] icons', () {
    test('[APP-07/AC2] every iOS AppIcon file exists, non-empty, no alpha', () {
      for (final set in ['AppIcon', 'AppIcon-dev', 'AppIcon-prod']) {
        final dir = '$ios/$set.appiconset';
        final contents = File('$dir/Contents.json')
            .readAsStringSync()
            .replaceAll(RegExp(r'\s'), '');
        final names = RegExp('"filename":"([^"]+)"')
            .allMatches(contents)
            .map((m) => m.group(1)!)
            .toSet();
        expect(names, isNotEmpty, reason: set);
        for (final name in names) {
          final f = File('$dir/$name');
          expect(_isNonEmptyPng(f), isTrue, reason: f.path);
          // PNG colour type at byte 25: 2 = RGB, 6 = RGBA.
          expect(f.readAsBytesSync()[25], 2, reason: '${f.path} has alpha');
        }
      }
    });

    test('[APP-07/AC2] launch image and flutter_launcher_icons sources', () {
      for (final f in [
        '$ios/LaunchImage.imageset/LaunchImage.png',
        '$ios/LaunchImage.imageset/LaunchImage@2x.png',
        '$ios/LaunchImage.imageset/LaunchImage@3x.png',
        'assets/icon/icon_prod.png',
        'assets/icon/icon_dev.png',
      ]) {
        expect(_isNonEmptyPng(File(f)), isTrue, reason: f);
      }
    });

    test('[APP-07/AC2] macOS AppIcon set is complete', () {
      final contents = File('$mac/Contents.json').readAsStringSync();
      final names = RegExp(r'"filename"\s*:\s*"([^"]+)"')
          .allMatches(contents)
          .map((m) => m.group(1)!)
          .toSet();
      expect(names.length, greaterThanOrEqualTo(7));
      for (final name in names) {
        expect(_isNonEmptyPng(File('$mac/$name')), isTrue, reason: name);
      }
    });

    test('[APP-07/AC2] Android legacy, adaptive and monochrome icons', () {
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        for (final n in [
          'ic_launcher',
          'ic_launcher_foreground',
          'ic_launcher_monochrome',
        ]) {
          final f = File('$res/mipmap-$d/$n.png');
          expect(_isNonEmptyPng(f), isTrue, reason: f.path);
        }
      }
      final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml')
          .readAsStringSync();
      expect(xml, contains('<foreground'));
      expect(xml, contains('<monochrome'));
      expect(xml, contains('<background'));
    });

    test('[APP-07/AC2] SVG masters and generator script exist', () {
      for (final f in [
        'lumen-icon.svg',
        'lumen-icon-dark.svg',
        'lumen-mark-light.svg',
        'lumen-mark-dark.svg',
        'lumen-wordmark-light.svg',
        'lumen-wordmark-dark.svg',
      ]) {
        expect(
          File('../design/brand/$f').lengthSync(),
          greaterThan(0),
          reason: f,
        );
      }
      expect(File('../tools/brand/make_icons.py').lengthSync(), greaterThan(0));
    });
  });

  group('[APP-07/AC3] upgrade in place keeps data', () {
    test('[APP-07/AC3] storage paths and channel names are unchanged', () {
      final paths = StoragePaths('/data/vv');
      expect(paths.dbFile, '/data/vv/db/vaultvoice.sqlite');
      expect(paths.modelsDir, '/data/vv/models');
      expect(paths.audioDir('r1'), '/data/vv/audio/r1');
      expect(paths.renderedFile('r1'), '/data/vv/rendered/r1.md');
      expect(secureStorageChannel, 'vaultvoice/secure_storage');
      expect(kBundleUti, 'com.vaultvoice.profile');
    });

    test('[APP-07/AC3] bundle ids and package name are unchanged', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "com.vaultvoice.vaultvoice"'));
      expect(gradle, contains('applicationIdSuffix = ".dev"'));
      final proj = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(
        proj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.vaultvoice.vaultvoice;'),
      );
      expect(
        proj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.vaultvoice.vaultvoice.dev;'),
      );
      expect(
        File('pubspec.yaml').readAsStringSync(),
        startsWith('name: vaultvoice'),
      );
    });
  });

  group('[APP-07/AC4] logo contrast', () {
    test('[APP-07/AC4] every logo foreground/background pair is >= 4.5:1', () {
      final pairs = <String, (Color, Color)>{
        'light mark on paper': (LumenColors.teal, LumenColors.paper),
        'light wordmark text on paper': (
          LumenColors.lightText,
          LumenColors.paper,
        ),
        'dark mark on ink': (LumenColors.mint, LumenColors.ink),
        'dark wordmark text on ink': (LumenColors.darkText, LumenColors.ink),
        'icon bars on teal': (LumenColors.mist, LumenColors.teal),
        'icon orb on teal': (LumenColors.glow, LumenColors.teal),
        'dark icon orb on ink': (LumenColors.glow, LumenColors.ink),
      };
      for (final MapEntry(key: name, value: pair) in pairs.entries) {
        expect(
          _ratio(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      }
    });

    test('[APP-07/AC4] SVG masters use the documented palette', () {
      String svg(String n) => File('../design/brand/$n').readAsStringSync();
      expect(svg('lumen-icon.svg'), contains('#0F766E'));
      expect(svg('lumen-icon-dark.svg'), contains('#0F1715'));
      expect(svg('lumen-mark-light.svg'), contains('#0F766E'));
      expect(svg('lumen-mark-dark.svg'), contains('#2DD4BF'));
    });

    testWidgets('[APP-07/AC4] wordmark renders in light and dark', (t) async {
      for (final mode in [Brightness.light, Brightness.dark]) {
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: mode),
            home: const Scaffold(body: Center(child: LumenWordmark())),
          ),
        );
        expect(find.text('Lumen'), findsOneWidget);
        expect(find.byType(LumenMark), findsOneWidget);
      }
    });
  });
}
