import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vv_native/vv_native.dart';

/// Directory on the device holding `ggml-tiny.en.bin` + `jfk.wav` from
/// `tools/ci/fetch_test_models.sh` (push them, then pass
/// `--dart-define=VV_TEST_MODELS_DIR=<device path>`).
const String kTestModelsDir = String.fromEnvironment('VV_TEST_MODELS_DIR');

/// On-device STT engine checks (STT-03). Device rows:
/// `docs/test-plans/device/STT-03.md`. Run:
///   cd app && fvm flutter test integration_test/stt_engine_test.dart \
///     --flavor dev -d DEVICE --dart-define=VV_TEST_MODELS_DIR=DIR
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = kTestModelsDir.isEmpty ? 'pass VV_TEST_MODELS_DIR' : null;

  Future<File> tiledWav(int times) async {
    final src = File('$kTestModelsDir/jfk.wav').readAsBytesSync();
    final view = ByteData.sublistView(src);
    var pos = 12;
    var data = Uint8List(0);
    while (pos + 8 <= src.length) {
      final id = String.fromCharCodes(src.sublist(pos, pos + 4));
      final len = view.getUint32(pos + 4, Endian.little);
      if (id == 'data') {
        data = src.sublist(pos + 8, pos + 8 + len);
        break;
      }
      pos += 8 + len + (len & 1);
    }
    final total = data.length * times;
    final h = ByteData(44)
      ..setUint32(0, 0x46464952, Endian.little)
      ..setUint32(4, 36 + total, Endian.little)
      ..setUint32(8, 0x45564157, Endian.little)
      ..setUint32(12, 0x20746d66, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 16000, Endian.little)
      ..setUint32(28, 32000, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x61746164, Endian.little)
      ..setUint32(40, total, Endian.little);
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/stt_tiled_$times.wav');
    final sink = out.openSync(mode: FileMode.write)
      ..writeFromSync(h.buffer.asUint8List());
    for (var i = 0; i < times; i++) {
      sink.writeFromSync(data);
    }
    sink.closeSync();
    return out;
  }

  WhisperSttEngine engine() {
    VvNative.open().loadBackends(gpuMask: VV_GPU_METAL);
    final e = WhisperSttEngine(
      modelId: 'ggml-tiny.en',
      modelPath: () async => '$kTestModelsDir/ggml-tiny.en.bin',
    );
    addTearDown(e.unload);
    return e;
  }

  testWidgets(
    '[STT-03/AC3] on-device: jfk keywords, 10-min live progress, cancel < 1 s, '
    'no frame > 16 ms',
    skip: skip != null,
    (tester) async {
      var progress = 0.0;
      final segments = <TranscriptSegment>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  const CircularProgressIndicator(),
                  LinearProgressIndicator(value: progress),
                  Text('${segments.length} segments'),
                ],
              ),
            ),
          ),
        ),
      );
      final e = engine();

      // 1. Keywords.
      final jfk = await e.transcribe('$kTestModelsDir/jfk.wav');
      expect(jfk.valueOrNull!.text.toLowerCase(), contains('country'));

      // 2. 10-min file with live progress + segments while measuring frames.
      final timings = <FrameTiming>[];
      void onTimings(List<FrameTiming> t) => timings.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(onTimings);
      final tenMin = await tiledWav(55); // 55 × 11 s ≈ 10 min
      final cancel = CancelToken();
      final sw = Stopwatch();
      final run = e.transcribe(
        tenMin.path,
        cancel: cancel,
        onProgress: (f) => progress = f,
        onSegment: segments.add,
      );
      // Keep frames flowing; cancel after 30 s of live segments.
      final until = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(until)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(segments, isNotEmpty, reason: 'live segments');
      expect(progress, greaterThan(0), reason: 'live progress');
      sw.start();
      cancel.cancel();
      final result = await run;
      sw.stop();
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
      expect(result.failureOrNull, isA<CancelledFailure>());
      expect(sw.elapsedMilliseconds, lessThan(1000));

      final spans = timings.map((t) => t.totalSpan.inMicroseconds).toList()
        ..sort();
      final p99 = spans.isEmpty ? 0 : spans[(spans.length * 0.99).floor()];
      binding.reportData = {
        'frames': spans.length,
        'p99_frame_us': p99,
        'cancel_ms': sw.elapsedMilliseconds,
        'segments_before_cancel': segments.length,
      };
      expect(p99, lessThanOrEqualTo(16000), reason: 'p99 build+raster');
    },
  );
}
