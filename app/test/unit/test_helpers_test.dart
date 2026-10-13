import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/deterministic.dart';
import '../helpers/fixtures.dart';
import '../helpers/golden.dart';
import '../helpers/pipeline_harness.dart';

/// Tests of the shared test helpers themselves (QA-01), so a broken helper
/// fails here rather than as a confusing failure in a feature test.
void main() {
  group('deterministic', () {
    test('test clock starts at the fixed epoch and only moves when told', () {
      final clock = testClock();
      expect(clock.now(), kTestEpoch);
      clock.advance(const Duration(minutes: 5));
      expect(clock.now(), kTestEpoch.add(const Duration(minutes: 5)));
    });

    test('seeded random repeats', () {
      final a = seededRandom();
      final b = seededRandom();
      expect(
        List.generate(5, (_) => a.nextInt(1000)),
        List.generate(5, (_) => b.nextInt(1000)),
      );
    });
  });

  group('fixtures', () {
    test('transcript fixture loads as timed segments', () {
      final segments = Fixtures.transcript('meeting_short');
      expect(segments, hasLength(4));
      expect(segments.first.start, Duration.zero);
      expect(segments.last.end, const Duration(seconds: 18));
      expect(segments[1].text, contains('Alex'));
    });

    test('missing fixture fails with its path', () {
      expect(
        () => Fixtures.readString('nope.json'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('nope'),
          ),
        ),
      );
    });

    test('synthWav is a valid 16 kHz mono PCM16 file', () {
      final wav = synthWav(duration: const Duration(milliseconds: 500));
      final b = ByteData.sublistView(wav);
      String ascii(int o) => String.fromCharCodes(wav.sublist(o, o + 4));
      expect(ascii(0), 'RIFF');
      expect(ascii(8), 'WAVE');
      expect(b.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(b.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(b.getUint32(24, Endian.little), 16000);
      expect(b.getUint16(34, Endian.little), 16);
      expect(b.getUint32(40, Endian.little), 8000 * 2);
      expect(wav.length, 44 + 16000);
      expect(synthWav(duration: const Duration(milliseconds: 500)), wav);
      final silence = ByteData.sublistView(synthWav(frequencyHz: 0));
      expect(
        List.generate(100, (i) => silence.getInt16(44 + i * 2, Endian.little)),
        everyElement(0),
      );
    });
  });

  group('pipeline harness', () {
    test('restart rebuilds the container but keeps work dir and fakes', () {
      final h = PipelineHarness();
      final first = h.container;
      h.file('vv.db').writeAsStringSync('state');

      final second = h.restart();

      expect(second, isNot(same(first)));
      expect(h.container, same(second));
      expect(h.restarts, 1);
      expect(h.file('vv.db').readAsStringSync(), 'state');
      expect(h.workDir.existsSync(), isTrue);
    });

    test('tokensOf splits text into fixed-size chunks', () {
      expect(tokensOf('abcdefghij', size: 4), ['abcd', 'efgh', 'ij']);
      expect(tokensOf(''), isEmpty);
    });
  });

  group('golden helpers', () {
    test('material fonts are found in the pinned Flutter SDK', () {
      expect(materialFontsDir().path, endsWith('material_fonts'));
    });

    test('golden variants cover both themes at 1.0 and 2.0', () {
      expect(GoldenTheme.values, hasLength(2));
      expect(kGoldenTextScales, [1.0, 2.0]);
      expect(kGoldenTolerance, lessThanOrEqualTo(0.001));
      expect(isGoldenReferenceHost, Platform.isLinux);
    });

    testWidgets('strict comparator: passes within tolerance, fails beyond', (
      t,
    ) async {
      await t.runAsync(() async {
        final dir = Directory.systemTemp.createTempSync('vv_golden_');
        addTearDown(() => dir.deleteSync(recursive: true));
        File('${dir.path}/ref.png').writeAsBytesSync(await _png(0));
        final cmp = TolerantGoldenComparator(
          Uri.file('${dir.path}/x_test.dart'),
          strict: true,
        );
        final golden = Uri.parse('ref.png');

        expect(await cmp.compare(await _png(0), golden), isTrue);
        // 1 of 10 000 pixels (0.01%) is within kGoldenTolerance.
        expect(await cmp.compare(await _png(1), golden), isTrue);
        // 100 pixels (1%) is a real change.
        await expectLater(
          cmp.compare(await _png(10), golden),
          throwsA(isA<FlutterError>()),
        );
      });
    });
  });
}

/// A 100×100 white PNG with a black [n]×[n] square in the corner.
Future<Uint8List> _png(int n) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = const Color(0xFFFFFFFF),
    )
    ..drawRect(
      Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );
  final image = await recorder.endRecording().toImage(100, 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
