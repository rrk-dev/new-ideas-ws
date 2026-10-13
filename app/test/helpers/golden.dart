import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';

/// Goldens are rendered and enforced on Linux (the CI `test` job).
/// macOS and Windows rasterise glyph edges differently, so a golden made on
/// one host never matches another pixel-for-pixel. Regenerate them with
/// `bash tools/ci/update_goldens.sh` (runs Linux in podman on a Mac).
bool get isGoldenReferenceHost => Platform.isLinux;

/// Max fraction of differing pixels on the reference host (absorbs x86_64 vs
/// arm64 rounding; one changed word on a 390×844 screen is ≈ 0.1%).
const double kGoldenTolerance = 0.0005;

/// On other hosts a mismatch beyond [kGoldenTolerance] marks the test
/// skipped instead of failing (CI still enforces it), unless
/// `VV_GOLDEN_STRICT=1` is set.
bool get goldenStrict =>
    isGoldenReferenceHost || Platform.environment['VV_GOLDEN_STRICT'] == '1';

/// Text scales every golden is rendered at (vv-testing: 1.0 and 2.0).
const List<double> kGoldenTextScales = [1.0, 2.0];

/// Logical surface used for screen goldens (iPhone 13-class portrait).
const Size kGoldenSurface = Size(390, 844);

/// Both app themes.
enum GoldenTheme {
  light,
  dark;

  ThemeData get data => this == light ? AppTheme.light : AppTheme.dark;
}

/// Renders [builder] in every [GoldenTheme] × [kGoldenTextScales] variant and
/// matches `goldens/<fileName>_<theme>_x<scale>.png` next to the test file.
/// Regenerate with `fvm flutter test --update-goldens --tags golden`.
void goldenTest(
  String description, {
  required String fileName,
  required WidgetBuilder builder,
  Size surface = kGoldenSurface,
  List<Override> overrides = const [],
}) {
  group(description, () {
    for (final theme in GoldenTheme.values) {
      for (final scale in kGoldenTextScales) {
        final variant = '${theme.name}_x${scale.toStringAsFixed(1)}';
        testWidgets('[$variant]', tags: ['golden'], (tester) async {
          tester.view
            ..physicalSize = surface
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          // Screens are Riverpod consumers (RecordScreen reads the flavor),
          // so every golden is pumped inside a ProviderScope.
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.data,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(builder: builder),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/${fileName}_$variant.png'),
          );
        });
      }
    }
  });
}

/// [LocalFileComparator] that accepts up to [tolerance] differing pixels and,
/// when not [strict], reports larger diffs as a skip instead of a failure.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(
    super.testFile, {
    this.tolerance = kGoldenTolerance,
    bool? strict,
  }) : strict = strict ?? goldenStrict;

  final double tolerance;
  final bool strict;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    if (!strict) {
      final pct = (result.diffPercent * 100).toStringAsFixed(2);
      result.dispose();
      markTestSkipped(
        'golden $golden differs by $pct% on ${Platform.operatingSystem}; '
        'goldens are enforced on Linux only (docs/testing.md)',
      );
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Swaps the per-file [LocalFileComparator] flutter_test installs for a
/// [TolerantGoldenComparator] rooted at the same test file directory.
void useTolerantGoldenComparator() {
  final current = goldenFileComparator;
  if (current is LocalFileComparator && current is! TolerantGoldenComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      current.basedir.resolve('golden_test.dart'),
    );
  }
}

/// Loads real fonts (Roboto + MaterialIcons, pinned by the FVM Flutter
/// version's `bin/cache/artifacts/material_fonts`) so goldens show text and
/// icons instead of the default test font's boxes. Throws if they are missing
/// — a golden silently rendered with placeholder glyphs is worse than none.
Future<void> loadTestFonts() async {
  final dir = materialFontsDir();
  final roboto = FontLoader('Roboto');
  final files = dir.listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name.startsWith('Roboto-') && name.endsWith('.ttf');
  }).toList()..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) throw StateError('no Roboto fonts in ${dir.path}');
  for (final f in files) {
    roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await roboto.load();
  final icons = File('${dir.path}/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

/// `<flutter root>/bin/cache/artifacts/material_fonts`, from `FLUTTER_ROOT`
/// or by walking up from the `flutter_tester` executable.
Directory materialFontsDir() {
  const rel = 'bin/cache/artifacts/material_fonts';
  final candidates = <Directory>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      Directory('$root/$rel'),
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    candidates.add(Directory('${dir.path}/$rel'));
    dir = dir.parent;
  }
  for (final c in candidates) {
    if (File('${c.path}/MaterialIcons-Regular.otf').existsSync()) return c;
  }
  throw StateError(
    'Flutter material_fonts not found (looked in ${candidates.first.path} '
    'and parents of ${Platform.resolvedExecutable}); run `fvm flutter '
    'precache` or set FLUTTER_ROOT.',
  );
}
