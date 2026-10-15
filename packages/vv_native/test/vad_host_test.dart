@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vv_native/vv_native.dart';

/// Host FFI tests for the VAD binding (AUD-03) against `native/build/host`
/// + `ggml-silero-v6.2.0.bin` / `ggml-tiny.en.bin` / `jfk.wav` from
/// `tools/ci/fetch_test_models.sh`.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String _modelsDir() =>
    Platform.environment['VV_TEST_MODELS_DIR'] ??
    '${Platform.environment['HOME']}/.cache/vaultvoice/test-models';

/// 16 kHz mono PCM16 WAV of [samples].
File _wav(Directory dir, String name, Int16List samples) {
  final b = BytesBuilder();
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  final data = samples.length * 2;
  b.add('RIFF'.codeUnits);
  u32(36 + data);
  b.add('WAVEfmt '.codeUnits);
  u32(16);
  u16(1);
  u16(1);
  u32(16000);
  u32(32000);
  u16(2);
  u16(16);
  b.add('data'.codeUnits);
  u32(data);
  b.add(samples.buffer.asUint8List());
  return File('${dir.path}/$name')..writeAsBytesSync(b.toBytes());
}

Int16List _jfkSamples(String wav) {
  // jfk.wav: canonical 44-byte header, PCM16 LE.
  final d = ByteData.sublistView(File(wav).readAsBytesSync(), 44);
  return Int16List.fromList([
    for (var i = 0; i + 1 < d.lengthInBytes; i += 2)
      d.getInt16(i, Endian.little),
  ]);
}

void main() {
  final lib = _hostLib();
  final vadModel = '${_modelsDir()}/ggml-silero-v6.2.0.bin';
  final sttModel = '${_modelsDir()}/ggml-tiny.en.bin';
  final jfk = '${_modelsDir()}/jfk.wav';
  final skip = lib == null
      ? 'run native/build.sh host first'
      : ![vadModel, jfk].every((p) => File(p).existsSync())
      ? 'run tools/ci/fetch_test_models.sh'
      : null;
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('vv_vad_host_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('[AUD-03] segments: silence → none; jfk → speech', () {
    final vad = VvVad.open(vadModel, hostPath: lib);
    addTearDown(vad.dispose);
    final silence = _wav(dir, 's.wav', Int16List(16000 * 5));
    expect(vad.segments([VvAudioRange(silence.path)]), isEmpty);
    final segs = vad.segments([VvAudioRange(jfk)]);
    expect(segs, isNotEmpty);
    expect(segs.first.startMs, lessThan(1500));
    expect(segs.last.endMs, inInclusiveRange(9000, 11100));
    expect(
      () => vad.segments([const VvAudioRange('/nope.wav')]),
      throwsA(isA<VvVadException>().having((e) => e.code, 'code', VV_E_IO)),
    );
  }, skip: skip);

  test('[AUD-03] streaming on its own isolate: one result per block, '
      'speech vs silence', () async {
    final s = await VvVadStream.spawn(vadModel, hostPath: lib);
    final results = <VvVadFeed>[];
    final sub = s.results.listen(results.add);
    for (var i = 0; i < 3; i++) {
      s.feed(Int16List(16000)); // 1 s silence
    }
    final speech = _jfkSamples(jfk);
    for (var i = 0; i + 16000 <= speech.length; i += 16000) {
      s.feed(Int16List.sublistView(speech, i, i + 16000));
    }
    await s.close();
    await sub.cancel();
    expect(results.length, 3 + speech.length ~/ 16000);
    expect(results.take(3).every((r) => r.speechWindows == 0), isTrue);
    final talk = results.skip(3).fold(0, (n, r) => n + r.speechWindows);
    expect(talk, greaterThan(100));
  }, skip: skip);

  test('missing model → VvVadException(MODEL_LOAD)', () async {
    expect(
      () => VvVad.open('/nope.bin', hostPath: lib),
      throwsA(
        isA<VvVadException>().having((e) => e.code, 'code', VV_E_MODEL_LOAD),
      ),
    );
    await expectLater(
      VvVadStream.spawn('/nope.bin', hostPath: lib),
      throwsA(isA<VvVadException>()),
    );
  }, skip: lib == null ? 'run native/build.sh host first' : null);

  test('[AUD-03/AC2] whisper with VAD returns no text on 30 s of noise and '
      'keeps original-timeline times', () async {
    VvNative.open(hostPath: lib).loadBackends();
    final w = await VvWhisper.load(sttModel, useGpu: false, hostPath: lib);
    addTearDown(w.dispose);
    final noise = Int16List(16000 * 30);
    var x = 1;
    for (var i = 0; i < noise.length; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      noise[i] = (x % 64) - 32;
    }
    final quiet = _wav(dir, 'noise.wav', noise);
    final events = await w.transcribe([
      VvAudioRange(quiet.path),
    ], params: VvSttParams(vadModelPath: vadModel)).toList();
    expect((events.last as VvSttDone).status, VV_OK);
    expect(events.whereType<VvSttSegment>(), isEmpty);

    final padded = Int16List(16000 * 15)
      ..setAll(0, Int16List(16000 * 10))
      ..setAll(16000 * 10, _jfkSamples(jfk).take(16000 * 5));
    final f = _wav(dir, 'padded.wav', padded);
    final segs = (await w.transcribe(
      [VvAudioRange(f.path)],
      params: VvSttParams(vadModelPath: vadModel),
    ).toList()).whereType<VvSttSegment>().toList();
    expect(segs, isNotEmpty);
    expect(segs.first.t0SrcMs, greaterThanOrEqualTo(9500));
  }, skip: skip ?? (File(sttModel).existsSync() ? null : 'no tiny.en'));
}
