import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vv_native/vv_native.dart';

class _FakeWhisper implements VvWhisper {
  _FakeWhisper({required this.gpu, required this.onRun});

  final bool gpu;
  final void Function(_FakeWhisper w) onRun;
  Completer<void>? _cancelled;
  bool disposed = false;

  @override
  bool get busy => false;

  @override
  Stream<VvSttEvent> transcribe(
    List<VvAudioRange> ranges, {
    VvSttParams params = const VvSttParams(),
  }) async* {
    onRun(this);
    if (gpu) {
      _cancelled = Completer<void>();
      await _cancelled!.future;
      yield const VvSttDone(VV_E_CANCELLED, 0, 0);
      return;
    }
    yield const VvSttSegment(
      index: 0,
      t0Ms: 0,
      t1Ms: 1000,
      t0Range: 0,
      t0SrcMs: 0,
      t1Range: 0,
      t1SrcMs: 1000,
      avgLogprob: -0.1,
      noSpeechProb: 0.01,
      text: 'cpu',
    );
    yield const VvSttDone(VV_OK, 1000, 10);
  }

  @override
  void cancel() => _cancelled?.complete();

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  test('[FND-08/AC3] [STT-03/AC1] backgrounding cancels a GPU decode in '
      'flight and restarts it on the CPU', () async {
    final dir = Directory.systemTemp.createTempSync('vv_stt_lifecycle');
    addTearDown(() => dir.deleteSync(recursive: true));
    final model = File('${dir.path}/m.bin')..writeAsBytesSync([0]);
    var foreground = true;
    final loads = <bool>[];
    final started = Completer<void>();
    final engine = WhisperSttEngine(
      modelId: 'm',
      modelPath: () async => model.path,
      useGpu: () => foreground,
      idleUnload: const Duration(hours: 1),
      loader: (path, {useGpu = true, hostPath}) async {
        loads.add(useGpu);
        return _FakeWhisper(
          gpu: useGpu,
          onRun: (w) {
            if (w.gpu && !started.isCompleted) started.complete();
          },
        );
      },
    );
    addTearDown(engine.unload);

    final pending = engine.transcribe('a.wav');
    await started.future.timeout(const Duration(seconds: 5));
    foreground = false;
    engine.onBackgrounded();
    final r = await pending.timeout(const Duration(seconds: 5));

    expect(loads, [true, false], reason: 'reloaded on the CPU');
    expect(r.valueOrNull?.segments.single.text, 'cpu');
  });
}
