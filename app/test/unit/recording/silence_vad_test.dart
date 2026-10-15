import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/data/silence_watcher.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/silence_monitor.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import '../../fakes/fake_call_guard.dart';
import '../../fakes/fake_capture_backend.dart';
import '../../helpers/deterministic.dart';

class _Pcm implements LivePcmSource {
  final c = StreamController<Uint8List>.broadcast(sync: true);

  @override
  Stream<Uint8List> get pcm => c.stream;
}

/// Scripted VAD: every fed block yields the next scripted answer
/// (default: all silence).
class _Vad implements LiveVad {
  final _r = StreamController<VadCounts>(sync: true);
  final fed = <int>[];
  bool speech = false;
  bool closed = false;

  @override
  void feed(Int16List pcm) {
    fed.add(pcm.length);
    final windows = pcm.length ~/ 512;
    _r.add((windows: windows, speech: speech ? windows : 0));
  }

  @override
  Stream<VadCounts> get results => _r.stream;

  @override
  Future<void> close() async {
    closed = true;
    await _r.close();
  }
}

void main() {
  group('SilenceMonitor', () {
    test('[AUD-03] auto-stop after the configured continuous silence; '
        'speech resets the counter', () {
      final m = SilenceMonitor(
        const SilencePolicy(autoStopAfter: Duration(minutes: 5)),
      );
      // 31 windows ≈ 1 s each.
      for (var s = 0; s < 4 * 60; s++) {
        expect(m.add(31, 0), isNull);
      }
      expect(m.add(31, 2), isNull, reason: 'speech');
      expect(m.silence, Duration.zero);
      SilenceAction? last;
      var seconds = 0;
      while (last == null) {
        last = m.add(31, 0);
        seconds++;
      }
      expect(last, SilenceAction.stop);
      expect(seconds, inInclusiveRange(302, 303)); // 5 min / 0.992 s
      expect(m.add(31, 0), isNull, reason: 'fires once');
    });

    test('auto-pause fires once per silence stretch; stop wins', () {
      final m = SilenceMonitor(
        const SilencePolicy(
          autoPauseAfter: Duration(seconds: 2),
          autoStopAfter: Duration(seconds: 4),
        ),
      );
      final actions = [for (var i = 0; i < 6; i++) m.add(31, 0)];
      expect(actions.whereType<SilenceAction>(), [
        SilenceAction.pause,
        SilenceAction.stop,
      ]);
      final both = SilenceMonitor(
        const SilencePolicy(
          autoPauseAfter: Duration(seconds: 1),
          autoStopAfter: Duration(seconds: 1),
        ),
      );
      expect(both.add(40, 0), SilenceAction.stop);
    });

    test('[AUD-03] VAD has no start/resume action (SEC-09)', () {
      expect(SilenceAction.values.map((a) => a.name), ['pause', 'stop']);
    });

    test('policy from settings', () {
      final p = SilencePolicy.fromSettings(autoPause: true, autoStop: 'off');
      expect(p.autoPauseAfter, SilencePolicy.defaultAutoPause);
      expect(p.autoStopAfter, isNull);
      expect(
        SilencePolicy.fromSettings(
          autoPause: false,
          autoStop: 'minutes_10',
        ).autoStopAfter,
        const Duration(minutes: 10),
      );
      expect(
        SilencePolicy.fromSettings(autoPause: false, autoStop: 'off').enabled,
        isFalse,
      );
    });
  });

  group('SilenceWatcher', () {
    late FakeCaptureBackend capture;
    late RecordingController controller;
    late _Pcm pcm;
    late _Vad vad;

    SilenceWatcher watcher(SilencePolicy policy, {bool model = true}) =>
        SilenceWatcher(
          controller: controller,
          pcm: pcm,
          policy: () async => policy,
          openVad: () async => model ? vad : null,
        )..attach();

    void setUpRig(FakeAsync async) {
      capture = FakeCaptureBackend();
      controller = RecordingController(
        capture: capture,
        callGuard: FakeCallGuard(),
        clock: testClock(),
        isAppInForeground: () => true,
      );
      pcm = _Pcm();
      vad = _Vad();
    }

    /// [seconds] of PCM in 100 ms blocks.
    void speak(FakeAsync async, int seconds) {
      for (var i = 0; i < seconds * 10; i++) {
        pcm.c.add(Uint8List(3200));
        async.flushMicrotasks();
      }
    }

    test('[AUD-03] auto-stop after silence: the recording is stopped with '
        'cause silence', () {
      fakeAsync((async) {
        setUpRig(async);
        final w = watcher(
          const SilencePolicy(autoStopAfter: Duration(seconds: 5)),
        );
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 4);
        expect(controller.state.phase, RecordingPhase.recording);
        speak(async, 2);
        expect(controller.state.phase, RecordingPhase.stopped);
        expect(controller.state.stopCause, StopCause.silence);
        expect(vad.fed.every((n) => n == 16000), isTrue, reason: '1 s feeds');
        async.flushMicrotasks();
        expect(vad.closed, isTrue);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
    });

    test('[AUD-03] auto-pause after silence never resumes on speech — only '
        'a user tap does (SEC-09)', () {
      fakeAsync((async) {
        setUpRig(async);
        final w = watcher(
          const SilencePolicy(autoPauseAfter: Duration(seconds: 3)),
        );
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 4);
        expect(controller.state.phase, RecordingPhase.paused);
        expect(controller.state.pauseCause, PauseCause.silence);
        expect(capture.suspends.single.gap, GapKind.silencePause);

        // Speech while paused: nothing reaches the VAD, nothing resumes.
        vad.speech = true;
        final fedBefore = vad.fed.length;
        speak(async, 3);
        async.elapse(const Duration(minutes: 10));
        expect(controller.state.phase, RecordingPhase.paused);
        expect(vad.fed.length, fedBefore);
        expect(capture.calls.whereType<ResumeCall>(), isEmpty);

        // The user taps Resume: silence counts from zero again.
        unawaited(controller.resume(ResumeSource.inAppButton));
        async.flushMicrotasks();
        expect(controller.state.phase, RecordingPhase.recording);
        vad.speech = false;
        speak(async, 2);
        expect(controller.state.phase, RecordingPhase.recording);
        speak(async, 2);
        expect(controller.state.phase, RecordingPhase.paused);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
    });

    test('[AUD-03] during a silence pause the stop deadline keeps running', () {
      fakeAsync((async) {
        setUpRig(async);
        final w = watcher(
          const SilencePolicy(
            autoPauseAfter: Duration(seconds: 2),
            autoStopAfter: Duration(seconds: 60),
          ),
        );
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 3);
        expect(controller.state.pauseCause, PauseCause.silence);
        async.elapse(const Duration(seconds: 50));
        expect(controller.state.phase, RecordingPhase.paused);
        async.elapse(const Duration(seconds: 15));
        expect(controller.state.phase, RecordingPhase.stopped);
        expect(controller.state.stopCause, StopCause.silence);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
    });

    test('a user pause is never turned into a stop', () {
      fakeAsync((async) {
        setUpRig(async);
        final w = watcher(
          const SilencePolicy(autoStopAfter: Duration(seconds: 5)),
        );
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 3);
        unawaited(controller.pause());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(hours: 1));
        expect(controller.state.phase, RecordingPhase.paused);
        expect(controller.state.pauseCause, PauseCause.user);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
    });

    test('unreadable settings leave silence detection off', () {
      fakeAsync((async) {
        setUpRig(async);
        final w = SilenceWatcher(
          controller: controller,
          pcm: pcm,
          policy: () async => throw StateError('closed'),
          openVad: () async => vad,
        )..attach();
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 3);
        expect(controller.state.phase, RecordingPhase.recording);
        expect(vad.fed, isEmpty);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
    });

    test('off without the VAD model or with both settings off', () {
      fakeAsync((async) {
        setUpRig(async);
        final w = watcher(
          const SilencePolicy(autoStopAfter: Duration(seconds: 1)),
          model: false,
        );
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 5);
        expect(controller.state.phase, RecordingPhase.recording);
        expect(vad.fed, isEmpty);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
      fakeAsync((async) {
        setUpRig(async);
        final w = watcher(SilencePolicy.off);
        unawaited(controller.start(StartSource.inAppButton));
        async.flushMicrotasks();
        speak(async, 5);
        expect(controller.state.phase, RecordingPhase.recording);
        expect(vad.fed, isEmpty);
        unawaited(w.dispose());
        async.flushMicrotasks();
      });
    });
  });
}
