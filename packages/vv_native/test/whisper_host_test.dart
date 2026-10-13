@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vv_native/vv_native.dart';

/// Host FFI tests for the STT engine binding (STT-03) against
/// `native/build/host` + `ggml-tiny.en.bin` / `jfk.wav` from
/// `tools/ci/fetch_test_models.sh` (`$VV_TEST_MODELS_DIR`, default
/// `~/.cache/vaultvoice/test-models`).
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

void main() {
  final lib = _hostLib();
  final model = '${_modelsDir()}/ggml-tiny.en.bin';
  final wav = '${_modelsDir()}/jfk.wav';
  final skip = lib == null
      ? 'run native/build.sh host first'
      : !File(model).existsSync() || !File(wav).existsSync()
      ? 'run tools/ci/fetch_test_models.sh ggml-tiny.en.bin jfk.wav'
      : null;

  // GPU on (Metal on macOS) unless VV_STT_GPU=0.
  final useGpu = Platform.environment['VV_STT_GPU'] != '0';

  setUpAll(() {
    if (skip == null) VvNative.open(hostPath: lib).loadBackends(gpuMask: 7);
  });

  Future<VvWhisper> load() =>
      VvWhisper.load(model, useGpu: useGpu, hostPath: lib);

  test('jfk.wav: keywords, monotonic timestamps, confidence', () async {
    final w = await load();
    final events = await w.transcribe([VvAudioRange(wav)]).toList();
    await w.dispose();
    final segs = events.whereType<VvSttSegment>().toList();
    final done = events.last as VvSttDone;
    expect(done.status, VV_OK);
    expect(done.audioMs, inInclusiveRange(10900, 11100));
    final text = segs.map((s) => s.text).join().toLowerCase();
    expect(text, contains('ask not'));
    expect(text, contains('country'));
    var prevEnd = 0;
    for (final (i, s) in segs.indexed) {
      expect(s.index, i);
      expect(s.t0Ms, greaterThanOrEqualTo(prevEnd));
      expect(s.t1Ms, greaterThanOrEqualTo(s.t0Ms));
      expect(s.t1Ms, lessThanOrEqualTo(11100));
      expect(s.avgLogprob, inExclusiveRange(-5, 0));
      prevEnd = s.t1Ms;
    }
  }, skip: skip);

  test(
    '[STT-03/AC1] live progress + segments, cancel stops within 1 s',
    () async {
      final w = await load();
      // ~5.5 min of audio: still running when cancelled.
      final ranges = List.filled(30, VvAudioRange(wav));
      final events = <VvSttEvent>[];
      final firstSegment = Completer<void>();
      final finished = Completer<VvSttDone>();
      w.transcribe(ranges).listen((e) {
        events.add(e);
        if (e is VvSttSegment && !firstSegment.isCompleted) {
          firstSegment.complete();
        }
        if (e is VvSttDone) finished.complete(e);
      });
      await firstSegment.future.timeout(const Duration(seconds: 60));
      final sw = Stopwatch()..start();
      w.cancel();
      final done = await finished.future.timeout(const Duration(seconds: 5));
      sw.stop();
      expect(done.status, VV_E_CANCELLED);
      expect(
        sw.elapsedMilliseconds,
        lessThan(1000),
        reason: 'cancel → VvSttDone must take < 1 s',
      );
      expect(events.whereType<VvSttProgress>(), isNotEmpty, reason: 'progress');
      expect(events.whereType<VvSttSegment>(), isNotEmpty, reason: 'segments');
      expect(w.busy, isFalse);
      // Handle reusable after a cancelled job.
      final again = await w.transcribe([VvAudioRange(wav)]).last;
      expect((again as VvSttDone).status, VV_OK);
      await w.dispose();
    },
    skip: skip,
  );

  test(
    '[STT-03/AC2] host proxy: transcription never blocks the calling isolate',
    () async {
      final w = await load();
      final sw = Stopwatch()..start();
      final stream = w.transcribe(List.filled(6, VvAudioRange(wav)));
      final startCall = sw.elapsedMicroseconds;
      // Measure event-loop gaps on this isolate while native code works.
      final gaps = <int>[];
      var last = sw.elapsedMicroseconds;
      final timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
        final now = sw.elapsedMicroseconds;
        gaps.add(now - last);
        last = now;
      });
      final done = (await stream.last) as VvSttDone;
      timer.cancel();
      final cancelSw = Stopwatch()..start();
      w.cancel(); // idle: no-op, must be instant
      cancelSw.stop();
      await w.dispose();
      expect(done.status, VV_OK);
      expect(startCall, lessThan(16000), reason: 'transcribe() sync part');
      expect(cancelSw.elapsedMicroseconds, lessThan(16000));
      gaps.sort();
      final p95 = gaps[(gaps.length * 0.95).floor()];
      expect(
        gaps.length,
        greaterThan(5),
        reason: 'event loop kept running during transcription',
      );
      expect(p95, lessThan(16000), reason: 'p95 event-loop gap (µs)');
    },
    skip: skip,
  );

  test('ranges map segments back to their source files', () async {
    final w = await load();
    final events = await w.transcribe([
      VvAudioRange(wav),
      VvAudioRange(wav, startMs: 2000),
    ]).toList();
    await w.dispose();
    final segs = events.whereType<VvSttSegment>().toList();
    expect((events.last as VvSttDone).audioMs, inInclusiveRange(19800, 20200));
    expect(segs.any((s) => s.t0Range == 1), isTrue);
    for (final s in segs.where((s) => s.t0Range == 1)) {
      expect(s.t0SrcMs, 2000 + s.t0Ms - 11000);
    }
  }, skip: skip);

  test('one job per handle; dispose while running ends the stream', () async {
    final w = await load();
    final stream = w.transcribe(List.filled(20, VvAudioRange(wav)));
    expect(
      () => w.transcribe([VvAudioRange(wav)]),
      throwsA(isA<VvSttException>().having((e) => e.code, 'code', VV_E_BUSY)),
    );
    final last = stream.last;
    await w.dispose();
    final done = (await last) as VvSttDone;
    expect(done.status, anyOf(VV_E_CANCELLED, VV_OK));
    expect(() => w.transcribe([VvAudioRange(wav)]), throwsStateError);
  }, skip: skip);

  test('bad model path and bad audio map to error codes', () async {
    await expectLater(
      VvWhisper.load('/nonexistent/ggml-x.bin', hostPath: lib),
      throwsA(
        isA<VvSttException>().having((e) => e.code, 'code', VV_E_MODEL_LOAD),
      ),
    );
    final w = await load();
    final missing = await w.transcribe([
      const VvAudioRange('/nonexistent/a.wav'),
    ]).last;
    expect((missing as VvSttDone).status, VV_E_IO);
    final notWav = await w.transcribe([VvAudioRange(model)]).last;
    expect((notWav as VvSttDone).status, VV_E_INVALID_ARG);
    await w.dispose();
  }, skip: skip);

  test('load/dispose 15× returns RSS to baseline (no model leak)', () async {
    final w0 = await load();
    await w0.dispose();
    final baseline = ProcessInfo.currentRss;
    for (var i = 0; i < 15; i++) {
      final w = await load();
      await w.dispose();
    }
    final grown = ProcessInfo.currentRss - baseline;
    // ggml-tiny.en is ~75 MB: 15 leaked contexts would be > 1 GB.
    expect(grown, lessThan(64 * 1024 * 1024), reason: 'RSS grew by $grown B');
  }, skip: skip);
}
