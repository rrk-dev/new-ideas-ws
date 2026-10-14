@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 45))
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vaultvoice/features/transcription/domain/hallucination_guards.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';
import 'package:vv_native/vv_native.dart';

/// STT-04 AC1 host evidence: a 2-hour recording (240 × 30 s chunk files,
/// jfk.wav + 1 s silence tiled) transcribed window by window through the
/// real bridge keeps the process RSS flat. Long (minutes), so opt-in:
/// `VV_STT04_2H=1 fvm flutter test test/native/long_form_memory_test.dart`
/// (needs `native/build.sh host` + `tools/ci/fetch_test_models.sh`). The
/// device row in docs/test-plans/device/STT-04.md is the acceptance run.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String _models() =>
    Platform.environment['VV_TEST_MODELS_DIR'] ??
    '${Platform.environment['HOME']}/.cache/vaultvoice/test-models';

Int16List _pcm(String path) {
  final b = File(path).readAsBytesSync();
  final view = ByteData.sublistView(b);
  var pos = 12;
  while (pos + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(pos, pos + 4));
    final len = view.getUint32(pos + 4, Endian.little);
    if (id == 'data') {
      return Uint8List.fromList(b.sublist(pos + 8, pos + 8 + len)).buffer
          .asInt16List();
    }
    pos += 8 + len + (len & 1);
  }
  throw StateError('no data chunk');
}

void main() {
  final lib = _hostLib();
  final model = '${_models()}/ggml-tiny.en.bin';
  final wav = '${_models()}/jfk.wav';
  final skip = Platform.environment['VV_STT04_2H'] != '1'
      ? 'opt-in: VV_STT04_2H=1 (takes minutes)'
      : lib == null
      ? 'run native/build.sh host first'
      : !File(model).existsSync() || !File(wav).existsSync()
      ? 'run tools/ci/fetch_test_models.sh ggml-tiny.en.bin jfk.wav'
      : null;

  test(
    '[STT-04/AC1] 2-hour recording: peak RSS stays flat across windows',
    () async {
      VvNative.open(hostPath: lib).loadBackends(gpuMask: VV_GPU_METAL);
      final tmp = Directory.systemTemp.createTempSync('vv_stt04_2h_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      // Tile period: jfk (≈11 s) + 1 s silence; speech spans per period.
      final jfk = _pcm(wav);
      final period = Int16List(jfk.length + 16000)..setAll(0, jfk);
      final periodMs = period.length ~/ 16;
      const totalMs = 2 * 3600 * 1000;
      const chunkMs = 30000;
      final chunks = <PlanChunk>[];
      for (var i = 0; i * chunkMs < totalMs; i++) {
        final pcm = Int16List(chunkMs * 16);
        for (var s = 0; s < pcm.length; s++) {
          pcm[s] = period[(i * chunkMs * 16 + s) % period.length];
        }
        final f = File('${tmp.path}/chunk_$i.wav')
          ..writeAsBytesSync([
            ...WavHeader.build(dataBytes: pcm.length * 2),
            ...pcm.buffer.asUint8List(),
          ]);
        chunks.add(
          PlanChunk(
            seq: i,
            path: f.path,
            startMs: i * chunkMs,
            endMs: (i + 1) * chunkMs,
          ),
        );
      }
      final speech = [
        for (var t = 0; t < totalMs; t += periodMs)
          SpeechSpan(t, min(totalMs, t + jfk.length ~/ 16)),
      ];
      final plan = planWindows(chunks: chunks, speech: speech);

      final engine = WhisperSttEngine(
        modelId: 'ggml-tiny.en',
        modelPath: () async => model,
        hostLibPath: lib,
        idleUnload: const Duration(minutes: 5),
      );
      addTearDown(engine.unload);
      final rss = <int>[];
      String? previous;
      var segments = 0;
      for (final w in plan.windows) {
        final r = await engine.transcribeRanges(
          [
            for (final x in w.ranges)
              SttAudioRange(
                path: x.path,
                startMs: x.fileStartMs,
                endMs: x.fileEndMs,
                recordingOffsetMs: x.recordingOffsetMs,
              ),
          ],
          options: SttOptions(
            initialPrompt: carryPrompt(previousText: previous),
          ),
        );
        final kept = applyGuards(
          r.valueOrNull!.segments,
          previous: previous,
        ).kept;
        segments += kept.length;
        if (kept.isNotEmpty) previous = kept.map((s) => s.text).join(' ');
        rss.add(ProcessInfo.currentRss);
      }
      final mb = [for (final b in rss) b ~/ (1024 * 1024)];
      final warm = mb.sublist(0, max(1, mb.length ~/ 4)).reduce(max);
      final late = mb.sublist(mb.length ~/ 2).reduce(max);
      // ignore: avoid_print
      print(
        'STT-04/AC1 windows=${plan.windows.length} segments=$segments '
        'rssMB first=${mb.first} warmMax=$warm lateMax=$late last=${mb.last} '
        'peak=${ProcessInfo.maxRss ~/ (1024 * 1024)}',
      );
      expect(segments, greaterThan(plan.windows.length));
      expect(late - warm, lessThanOrEqualTo(64), reason: 'RSS must not grow');
    },
    skip: skip,
  );
}
