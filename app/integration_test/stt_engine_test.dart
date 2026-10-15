import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vv_native/vv_native.dart';

import 'support/stt_live_harness.dart';

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

  Future<SttLiveReport> liveRun(
    WidgetTester tester,
    WhisperSttEngine e, {
    required Duration minLive,
  }) async {
    final tenMin = await tiledWav(55); // 55 × 11 s ≈ 10 min
    final state = SttLiveState();
    final cancel = CancelToken();
    return await runLiveAndCancel(
      tester,
      state: state,
      cancel: cancel,
      minLive: minLive,
      minSegments: 3,
      start: () => e.transcribe(
        tenMin.path,
        cancel: cancel,
        onProgress: state.onProgress,
        onSegment: state.onSegment,
      ),
    );
  }

  testWidgets(
    '[STT-03/AC1] [STT-03/AC3] on-device: jfk keywords; 10-min file shows '
    'live progress + segments on screen; cancel while running stops < 1 s',
    skip: skip != null,
    (tester) async {
      final e = engine();
      final jfk = await e.transcribe('$kTestModelsDir/jfk.wav');
      expect(jfk.valueOrNull!.text.toLowerCase(), contains('country'));

      // Cancel as soon as ≥ 3 s live and ≥ 3 segments are displayed; a run
      // that finishes first is a failure, not a pass.
      final r = await liveRun(tester, e, minLive: const Duration(seconds: 3));
      binding.reportData = {...?binding.reportData, ...r.toReportData()};
      expect(liveUiProblems(r), isEmpty);
    },
  );

  testWidgets(
    '[STT-03/AC2] [STT-03/AC3] on-device (profile mode): p99 build+raster '
    '≤ 16 ms over ≥ 10 s of live transcription',
    // Debug-mode frame timings say nothing about jank: run this one with
    // `flutter drive --profile` (docs/test-plans/device/STT-03.md).
    skip: skip != null || !kProfileMode,
    (tester) async {
      final e = engine();
      final spans = <int>[];
      void onTimings(List<FrameTiming> t) =>
          spans.addAll(t.map((f) => f.totalSpan.inMicroseconds));
      SchedulerBinding.instance.addTimingsCallback(onTimings);
      final SttLiveReport live;
      try {
        live = await liveRun(tester, e, minLive: const Duration(seconds: 10));
        // FrameTimings arrive in batches (≤ 1 s in profile mode): flush.
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(onTimings);
      }
      final r = live.withFrames(spans);
      binding.reportData = {...?binding.reportData, ...r.toReportData()};
      expect(liveUiProblems(r), isEmpty);
      expect(frameBudgetProblems(r), isEmpty);
    },
  );
}
