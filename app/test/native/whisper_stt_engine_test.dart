@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vv_native/vv_native.dart';

/// Real whisper.cpp through the host build of the bridge (STT-03):
/// `native/build.sh host` + `tools/ci/fetch_test_models.sh ggml-tiny.en.bin
/// jfk.wav`. Skipped when either is missing (app CI job without native).
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String _modelsDir() =>
    Platform.environment['VV_TEST_MODELS_DIR'] ??
    '${Platform.environment['HOME']}/.cache/vaultvoice/test-models';

/// Writes [wav]'s samples [times]× into one 16 kHz mono WAV.
File _tiledWav(String wav, int times, Directory dir) {
  final src = File(wav).readAsBytesSync();
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
  final header = ByteData(44)
    ..setUint32(0, 0x46464952, Endian.little) // RIFF
    ..setUint32(4, 36 + total, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little) // WAVE
    ..setUint32(12, 0x20746d66, Endian.little) // fmt
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 16000, Endian.little)
    ..setUint32(28, 32000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little) // data
    ..setUint32(40, total, Endian.little);
  final out = File('${dir.path}/tiled_$times.wav');
  final sink = out.openSync(mode: FileMode.write)
    ..writeFromSync(header.buffer.asUint8List());
  for (var i = 0; i < times; i++) {
    sink.writeFromSync(data);
  }
  sink.closeSync();
  return out;
}

void main() {
  final lib = _hostLib();
  final model = '${_modelsDir()}/ggml-tiny.en.bin';
  final wav = '${_modelsDir()}/jfk.wav';
  final skip = lib == null
      ? 'run native/build.sh host first'
      : !File(model).existsSync() || !File(wav).existsSync()
      ? 'run tools/ci/fetch_test_models.sh ggml-tiny.en.bin jfk.wav'
      : null;
  late Directory tmp;

  setUpAll(() {
    if (skip != null) return;
    VvNative.open(hostPath: lib).loadBackends(gpuMask: VV_GPU_METAL);
    tmp = Directory.systemTemp.createTempSync('vv_stt_');
  });
  tearDownAll(() {
    if (skip == null) tmp.deleteSync(recursive: true);
  });

  WhisperSttEngine engine({
    String? path,
    bool Function()? useGpu,
    Duration idle = const Duration(seconds: 5),
  }) {
    final e = WhisperSttEngine(
      modelId: 'ggml-tiny.en',
      modelPath: () async => path ?? model,
      useGpu: useGpu,
      idleUnload: idle,
      hostLibPath: lib,
    );
    addTearDown(e.unload);
    return e;
  }

  test(
    '[STT-03/AC1] live progress + segments; CancelToken stops within 1 s',
    () async {
      final e = engine();
      // Full run: live callbacks before the result.
      final progress = <double>[];
      final live = <TranscriptSegment>[];
      final ok = await e.transcribe(
        wav,
        onProgress: progress.add,
        onSegment: live.add,
      );
      final transcript = ok.valueOrNull!;
      expect(transcript.text.toLowerCase(), contains('ask not'));
      expect(transcript.text.toLowerCase(), contains('country'));
      expect(live, hasLength(transcript.segments.length));
      expect(progress, isNotEmpty);
      expect(progress.last, lessThanOrEqualTo(1.0));
      expect(transcript.segments.first.avgLogprob, isNotNull);
      for (var i = 1; i < transcript.segments.length; i++) {
        expect(
          transcript.segments[i].start,
          greaterThanOrEqualTo(transcript.segments[i - 1].end),
        );
      }

      // Cancel a ~5.5 min file once the first segment arrived.
      final long = _tiledWav(wav, 30, tmp);
      final cancel = CancelToken();
      final sw = Stopwatch();
      final result = await e.transcribe(
        long.path,
        cancel: cancel,
        onSegment: (_) {
          if (!cancel.isCancelled) {
            sw.start();
            cancel.cancel();
          }
        },
      );
      sw.stop();
      expect(result.failureOrNull, isA<CancelledFailure>());
      expect(
        sw.elapsedMilliseconds,
        lessThan(1000),
        reason: 'CancelToken.cancel → Err(CancelledFailure) must take < 1 s',
      );
    },
    skip: skip,
  );

  test(
    'missing model → ModelMissingFailure; corrupt model → NativeFailure',
    () async {
      final missing = await engine(path: '${tmp.path}/nope.bin')
          .transcribe(wav);
      expect(missing.failureOrNull, isA<ModelMissingFailure>());
      final bad = File('${tmp.path}/bad.bin')..writeAsStringSync('not a model');
      final corrupt = await engine(path: bad.path).transcribe(wav);
      expect(
        corrupt.failureOrNull,
        isA<NativeFailure>().having((f) => f.code, 'code', VV_E_MODEL_LOAD),
      );
      final notAudio = await engine().transcribe(bad.path);
      expect(notAudio.failureOrNull, isA<NativeFailure>());
      final noFile = await engine().transcribe('${tmp.path}/missing.wav');
      expect(noFile.failureOrNull, isA<StorageFailure>());
    },
    skip: skip,
  );

  test('model stays loaded between calls, unloads when idle or on demand; '
      'GPU→CPU switch reloads', () async {
    var gpu = true;
    final e = engine(
      useGpu: () => gpu,
      idle: const Duration(milliseconds: 300),
    );
    expect(e.loaded, isFalse);
    expect((await e.transcribe(wav)).isOk, isTrue);
    expect(e.loaded, isTrue, reason: 'kept for the next chunk');
    gpu = false; // app went to background
    final cpu = await e.transcribe(wav);
    expect(cpu.valueOrNull!.text.toLowerCase(), contains('country'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(e.loaded, isFalse, reason: 'idle unload frees the model');
    expect((await e.transcribe(wav)).isOk, isTrue);
    await e.unload();
    expect(e.loaded, isFalse);
  }, skip: skip);

  test('concurrent calls are serialised, never VV_E_BUSY', () async {
    final e = engine();
    final results = await Future.wait([
      e.transcribe(wav),
      e.transcribe(wav),
      e.transcribe(wav),
    ]);
    for (final r in results) {
      expect(r, isA<Ok<Transcript>>());
    }
  }, skip: skip);
}
