import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Iterable<File> _dartFiles(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

void main() {
  test('[APP-08/AC1] themes are defined once, in lib/core/theme', () {
    final offenders = <String>[];
    for (final f in _dartFiles('lib')) {
      if (f.path.startsWith('lib/core/theme/')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'\bThemeData\(|ColorScheme\.from|\bColorScheme\(')
          .hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.useMaterial3, isTrue);
  });

  test('[APP-08/AC1] features contain no raw Color(0x…) literals', () {
    final offenders = <String>[];
    for (final f in _dartFiles('lib/features')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(
          r'\bColor\(\s*0x',
          caseSensitive: false,
        ).hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  group('[APP-08/AC2] WCAG AA contrast of the colour tokens', () {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test(name, () {
        final s = theme.colorScheme;
        final x = theme.extension<LumenExtras>()!;
        final surfaces = [
          s.surface,
          s.surfaceContainerLowest,
          s.surfaceContainerLow,
          s.surfaceContainer,
          s.surfaceContainerHigh,
          s.surfaceContainerHighest,
        ];
        final body = <(Color, Color, String)>[
          for (final bg in surfaces) ...[
            (s.onSurface, bg, 'onSurface'),
            (s.onSurfaceVariant, bg, 'onSurfaceVariant'),
            (s.primary, bg, 'primary text'),
            (s.error, bg, 'error text'),
          ],
          (s.onPrimary, s.primary, 'onPrimary'),
          (s.onPrimaryContainer, s.primaryContainer, 'onPrimaryContainer'),
          (s.onSecondary, s.secondary, 'onSecondary'),
          (s.onSecondaryContainer, s.secondaryContainer, 'onSecondaryCont.'),
          (s.onTertiaryContainer, s.tertiaryContainer, 'onTertiaryCont.'),
          (s.onError, s.error, 'onError'),
          (s.onErrorContainer, s.errorContainer, 'onErrorContainer'),
          (s.onInverseSurface, s.inverseSurface, 'onInverseSurface'),
          (s.inversePrimary, s.inverseSurface, 'snackbar action'),
          (x.onGlow, x.glow, 'onGlow'),
          (x.onRecording, x.recording, 'onRecording'),
        ];
        for (final (fg, bg, what) in body) {
          expect(
            _ratio(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$what: $fg on $bg',
          );
        }
        // Controls and borders: 3:1 against the page.
        for (final (fg, what) in [
          (s.outline, 'outline'),
          (s.primary, 'primary control'),
        ]) {
          expect(_ratio(fg, s.surface), greaterThanOrEqualTo(3), reason: what);
          expect(
            _ratio(fg, s.surfaceContainerLowest),
            greaterThanOrEqualTo(3),
            reason: '$what on cards',
          );
        }
      });
    }
  });

  test('[APP-08/AC4] screen goldens exist in light and dark', () {
    for (final screen in [
      'onboarding_privacy',
      'record_screen',
      'library_screen',
      'settings_screen',
      'models_screen',
    ]) {
      for (final mode in ['light', 'dark']) {
        expect(
          File('test/golden/goldens/${screen}_${mode}_x1.0.png').existsSync(),
          isTrue,
          reason: '$screen $mode',
        );
      }
    }
  });

  test('[APP-08/AC5] restyle keeps behaviour: 48 dp targets, no shadows', () {
    for (final t in [AppTheme.light, AppTheme.dark]) {
      final size = t.filledButtonTheme.style!.minimumSize!.resolve({});
      expect(size!.height, greaterThanOrEqualTo(kMinTapTarget));
      expect(t.cardTheme.elevation, AppElevation.none);
    }
  });
}
