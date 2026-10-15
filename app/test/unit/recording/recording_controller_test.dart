// Each step is a separate statement on purpose (reads like a script).
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_limits.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import '../../fakes/fake_call_guard.dart';
import '../../fakes/fake_capture_backend.dart';

/// [Clock] driven by the surrounding [FakeAsync] zone.
class _AsyncClock implements Clock {
  _AsyncClock(this._async);

  final FakeAsync _async;
  static final _origin = DateTime.utc(2026, 10, 12, 9);

  @override
  DateTime now() => _origin.add(_async.elapsed);
}

class _Reminders implements RecordingReminderSink {
  final shown = <Duration>[];

  @override
  void stillRecording(Duration elapsed) => shown.add(elapsed);
}

class _Harness {
  _Harness(this.async, {RecordingLimits? limits}) : clock = _AsyncClock(async) {
    controller = RecordingController(
      capture: capture,
      callGuard: guard,
      clock: clock,
      isAppInForeground: () => foreground,
      limits: limits,
      reminders: reminders,
    );
  }

  final FakeAsync async;
  final _AsyncClock clock;
  final capture = FakeCaptureBackend();
  final guard = FakeCallGuard();
  final reminders = _Reminders();
  bool foreground = true;
  late final RecordingController controller;

  RecordingPhase get phase => controller.state.phase;

  /// Runs [f] to completion inside the fake-async zone.
  T run<T>(Future<T> Function() f) {
    T? out;
    var done = false;
    unawaited(
      f().then((v) {
        out = v;
        done = true;
      }),
    );
    async.flushMicrotasks();
    expect(done, isTrue, reason: 'future did not complete');
    return out as T;
  }

  Result<void> start([StartSource s = StartSource.inAppButton]) =>
      run(() => controller.start(s));
}

RecordingBlockReason? _reason(Result<Object?> r) => switch (r.failureOrNull) {
  RecordingBlockedFailure(:final reason) => reason,
  _ => null,
};

void main() {
  group('stop ordering', () {
    test('[AUD-01/AC1] stopped is announced only after capture finalized, so '
        'transcription never reads incomplete chunks', () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(h.start().isOk, isTrue);
        final seen = <RecordingPhase>[];
        h.controller.states.listen((s) => seen.add(s.phase));
        h.capture.closeGate = Completer<void>();
        unawaited(h.controller.stop());
        async.flushMicrotasks();
        expect(seen, isNot(contains(RecordingPhase.stopped)));
        h.capture.closeGate!.complete();
        async.flushMicrotasks();
        expect(seen, contains(RecordingPhase.stopped));
      });
    });
  });

  group('start refused during calls', () {
    test('[SEC-09/AC2] start is refused while a call rings or is active; '
        'the microphone is never opened', () {
      fakeAsync((async) {
        final h = _Harness(async)..guard.inCall = true;
        final r = h.start();
        expect(_reason(r), RecordingBlockReason.inCall);
        expect(h.capture.calls, isEmpty);
        expect(h.capture.micOpen, isFalse);
        expect(h.phase, RecordingPhase.idle);
        expect(h.guard.hasListener, isFalse);

        h.guard.inCall = false;
        expect(h.start().isOk, isTrue);
        expect(h.capture.calls.single, isA<OpenCall>());
      });
    });

    test('[SEC-09/AC2] start fails closed when the call state is unknown', () {
      fakeAsync((async) {
        final h = _Harness(async)..guard.unavailable = true;
        expect(_reason(h.start()), RecordingBlockReason.callGuardUnavailable);
        expect(h.capture.calls, isEmpty);
      });
    });

    test('[SEC-09/AC2] a call that starts while the start is checked '
        'refuses the start', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.guard.onQuery = () {
          h.guard.inCall = false; // the query still answers "no call" …
          h.guard
            ..emit(CallGuardSignal.callActive, h.clock.now())
            ..inCall = false; // … but the event arrived meanwhile.
        };
        expect(_reason(h.start()), RecordingBlockReason.inCall);
        expect(h.capture.calls, isEmpty);
      });
    });
  });

  group('guard drives capture', () {
    test('[SEC-09/AC3] a call while recording suspends capture immediately, '
        'dropping audio from the call start; call_interruption gap', () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(h.start().isOk, isTrue);
        async.elapse(const Duration(minutes: 3));

        final ringAt = h.clock.now();
        final before = async.elapsed;
        h.guard.emit(CallGuardSignal.callActive, ringAt);
        async.flushMicrotasks();

        // Reacted with zero timer time passing: well within the 500 ms budget.
        expect(async.elapsed - before, Duration.zero);
        final suspend = h.capture.suspends.single;
        expect(suspend.gap, GapKind.callInterruption);
        expect(suspend.gap.wireName, 'call_interruption');
        expect(suspend.discardFrom, ringAt);
        expect(h.capture.micOpen, isFalse);
        expect(h.phase, RecordingPhase.paused);
        expect(h.controller.state.pauseCause, PauseCause.call);
        expect(h.controller.elapsed, const Duration(minutes: 3));
      });
    });

    test('[SEC-09/AC3] after the call ends the recording stays paused '
        '(never auto-resumes)', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.start();
        h.guard.emit(CallGuardSignal.callActive, h.clock.now());
        async.elapse(const Duration(minutes: 2));
        h.guard
          ..emit(CallGuardSignal.callEnded, h.clock.now())
          ..emit(CallGuardSignal.interruptionEnded, h.clock.now())
          ..emit(CallGuardSignal.captureUnsilenced, h.clock.now());
        async.elapse(const Duration(hours: 1));

        expect(h.capture.calls.whereType<ResumeCall>(), isEmpty);
        expect(h.capture.micOpen, isFalse);
        expect(h.phase, RecordingPhase.paused);
        expect(h.controller.elapsed, Duration.zero);
      });
    });

    test('[SEC-09/AC3] resume needs a user tap and is refused while the call '
        'is still active', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.start();
        h.guard.emit(CallGuardSignal.callActive, h.clock.now());
        async.flushMicrotasks();

        final early = h.run(
          () => h.controller.resume(ResumeSource.inAppButton),
        );
        expect(_reason(early), RecordingBlockReason.inCall);
        expect(h.capture.calls.whereType<ResumeCall>(), isEmpty);

        h.guard.emit(CallGuardSignal.callEnded, h.clock.now());
        final tap = h.run(() => h.controller.resume(ResumeSource.inAppButton));
        expect(tap.isOk, isTrue);
        expect(h.capture.calls.last, isA<ResumeCall>());
        expect(h.phase, RecordingPhase.recording);
      });
    });

    test('[SEC-09/AC3] audio-session interruption and silenced capture also '
        'suspend capture with their own gap kinds', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.start();
        final t1 = h.clock.now();
        h.guard.emit(CallGuardSignal.interruptionBegan, t1);
        expect(h.controller.state.pauseCause, PauseCause.audioInterruption);
        h.guard.emit(CallGuardSignal.interruptionEnded, t1);
        h.run(() => h.controller.resume(ResumeSource.inAppButton));

        async.elapse(const Duration(seconds: 5));
        final t2 = h.clock.now();
        h.guard.emit(CallGuardSignal.captureSilenced, t2);
        async.flushMicrotasks();

        expect(h.capture.suspends.map((s) => (s.gap, s.discardFrom)), [
          (GapKind.audioInterruption, t1),
          (GapKind.captureSilenced, t2),
        ]);
        expect(h.controller.state.pauseCause, PauseCause.captureSilenced);
      });
    });

    test('[SEC-09/AC3] a call that rings while the microphone is opening is '
        'applied as soon as it is open', () {
      fakeAsync((async) {
        final h = _Harness(async);
        late DateTime ringAt;
        h.capture.onOpen = () {
          ringAt = h.clock.now();
          h.guard.emit(CallGuardSignal.callActive, ringAt);
        };
        expect(h.start().isOk, isTrue);
        expect(h.phase, RecordingPhase.paused);
        expect(h.capture.suspends.single.discardFrom, ringAt);
      });
    });
  });

  group('user-started only', () {
    test('[SEC-09/AC4] StartSource holds exactly the user-tap sources', () {
      expect(StartSource.values.map((s) => s.name).toSet(), {
        'inAppButton',
        'homeScreenWidget',
        'androidQuickSettingsTile',
        'iosControl',
      });
      expect(allowedStartSources, StartSource.values.toSet());
      expect(ResumeSource.values.map((s) => s.name).toSet(), {
        'inAppButton',
        'recordingNotification',
      });
      final automation = RegExp(
        'auto|schedul|timer|alarm|geo|locat|voice|vad|speech|push|remote|mdm|'
        'launch|background|headless|shortcut|intent|deeplink|boot',
        caseSensitive: false,
      );
      for (final name in [
        ...StartSource.values.map((s) => s.name),
        ...ResumeSource.values.map((s) => s.name),
      ]) {
        expect(automation.hasMatch(name), isFalse, reason: name);
      }
    });

    test('[SEC-09/AC4] no microphone access and no guard work before the '
        'tap (no pre-capture)', () {
      fakeAsync((async) {
        final h = _Harness(async);
        async.elapse(const Duration(minutes: 10));
        expect(h.capture.calls, isEmpty);
        expect(h.guard.queries, 0);
        expect(h.guard.hasListener, isFalse);
      });
    });

    test('[SEC-09/AC4] start is refused from a background/headless '
        'context', () {
      fakeAsync((async) {
        final h = _Harness(async)..foreground = false;
        expect(_reason(h.start()), RecordingBlockReason.notForeground);
        expect(h.capture.calls, isEmpty);
        expect(h.guard.queries, 0);
      });
    });

    test('[SEC-09/AC4] start/resume/pause in the wrong phase are refused', () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(
          _reason(h.run(() => h.controller.resume(ResumeSource.inAppButton))),
          RecordingBlockReason.invalidState,
        );
        expect(
          _reason(h.run(h.controller.pause)),
          RecordingBlockReason.invalidState,
        );
        h.start();
        expect(_reason(h.start()), RecordingBlockReason.invalidState);
        expect(h.capture.calls.whereType<OpenCall>(), hasLength(1));
      });
    });

    test('[SEC-09/AC4] a microphone failure leaves the controller idle', () {
      fakeAsync((async) {
        final h = _Harness(async)
          ..capture.failWith(const PermissionFailure('microphone'));
        expect(h.start().failureOrNull, isA<PermissionFailure>());
        expect(h.phase, RecordingPhase.idle);
        expect(h.guard.hasListener, isFalse);
      });
    });
  });

  group('long-session safeguards', () {
    test('[SEC-09/AC5] stops automatically at the 4 h default, paused time '
        'excluded', () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(h.controller.limits.maxDuration, const Duration(hours: 4));
        h.start();
        async.elapse(const Duration(hours: 1));
        h.run(h.controller.pause);
        async.elapse(const Duration(hours: 2));
        h.run(() => h.controller.resume(ResumeSource.inAppButton));
        async.elapse(const Duration(hours: 2, minutes: 59, seconds: 58));
        expect(h.phase, RecordingPhase.recording);

        async.elapse(const Duration(seconds: 3));
        expect(h.phase, RecordingPhase.stopped);
        expect(h.controller.state.stopCause, StopCause.maxDuration);
        expect(h.capture.calls.last, isA<CloseCall>());
        expect(h.controller.elapsed, const Duration(hours: 4));
      });
    });

    test('[SEC-09/AC5] max duration is user-configurable up to 8 h', () {
      expect(
        RecordingLimits(maxDuration: const Duration(hours: 12)).maxDuration,
        RecordingLimits.maxDurationCeiling,
      );
      expect(RecordingLimits.maxDurationCeiling, const Duration(hours: 8));
      fakeAsync((async) {
        final h = _Harness(
          async,
          limits: RecordingLimits(maxDuration: const Duration(hours: 6)),
        );
        h.start();
        async.elapse(const Duration(hours: 5, minutes: 59));
        expect(h.phase, RecordingPhase.recording);
        async.elapse(const Duration(minutes: 2));
        expect(h.controller.state.stopCause, StopCause.maxDuration);
      });
    });

    test('[SEC-09/AC5] "Still recording" reminder every 60 min, only while '
        'backgrounded', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.start();
        h.foreground = false;
        async.elapse(const Duration(minutes: 59));
        expect(h.reminders.shown, isEmpty);
        async.elapse(const Duration(minutes: 1, seconds: 1));
        expect(h.reminders.shown, hasLength(1));
        expect(
          stillRecordingText(h.reminders.shown.single),
          'Still recording (1h 00m)',
        );

        h.foreground = true;
        async.elapse(const Duration(hours: 1));
        expect(h.reminders.shown, hasLength(1));

        h.foreground = false;
        async.elapse(const Duration(hours: 1));
        expect(h.reminders.shown, hasLength(2));
        expect(
          stillRecordingText(h.reminders.shown.last),
          startsWith('Still recording (3h 00m'),
        );
      });
    });

    test('[SEC-09/AC5] stops after the configured continuous silence', () {
      fakeAsync((async) {
        final h = _Harness(
          async,
          limits: RecordingLimits(silenceAutoStop: const Duration(minutes: 10)),
        );
        h.start();
        h.controller.reportContinuousSilence(const Duration(minutes: 9));
        async.flushMicrotasks();
        expect(h.phase, RecordingPhase.recording);
        h.controller.reportContinuousSilence(const Duration(minutes: 10));
        async.flushMicrotasks();
        expect(h.controller.state.stopCause, StopCause.silence);
        expect(h.capture.calls.last, isA<CloseCall>());
      });
    });
  });

  group('capture notices (AUD-01)', () {
    test('low storage stops and finalizes with the lowStorage cause', () {
      fakeAsync((async) {
        final h = _Harness(async);
        final seen = <CaptureNotice>[];
        h.controller.notices.listen(seen.add);
        expect(h.start().isOk, isTrue);
        h.capture.notify(CaptureNotice.lowStorageWarning);
        async.flushMicrotasks();
        expect(h.phase, RecordingPhase.recording);
        h.capture.notify(CaptureNotice.lowStorageStop);
        async.flushMicrotasks();
        expect(h.phase, RecordingPhase.stopped);
        expect(h.controller.state.stopCause, StopCause.lowStorage);
        expect((h.capture.calls.last as CloseCall).cause, StopCause.lowStorage);
        expect(seen, [
          CaptureNotice.lowStorageWarning,
          CaptureNotice.lowStorageStop,
        ]);
      });
    });

    test('an OS interruption or stream failure pauses; nothing resumes '
        'without a tap', () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(h.start().isOk, isTrue);
        h.capture.notify(CaptureNotice.interrupted);
        async.flushMicrotasks();
        expect(h.phase, RecordingPhase.paused);
        expect(h.controller.state.pauseCause, PauseCause.audioInterruption);
        expect(h.capture.suspends.single.gap, GapKind.audioInterruption);
        h.guard.emit(CallGuardSignal.interruptionEnded, h.clock.now());
        async.elapse(const Duration(minutes: 1));
        expect(h.phase, RecordingPhase.paused);
        expect(h.capture.micOpen, isFalse);

        expect(
          h.run(() => h.controller.resume(ResumeSource.inAppButton)).isOk,
          isTrue,
        );
        h.capture.notify(CaptureNotice.captureFailed);
        async.flushMicrotasks();
        expect(h.controller.state.pauseCause, PauseCause.captureError);
        expect(h.capture.suspends.last.gap, GapKind.captureError);
        // A notice while already paused changes nothing.
        h.capture.notify(CaptureNotice.interrupted);
        async.flushMicrotasks();
        expect(h.capture.suspends, hasLength(2));
      });
    });

    test('stop passes the cause to the capture', () {
      fakeAsync((async) {
        final h = _Harness(async);
        expect(h.start().isOk, isTrue);
        h.run(() => h.controller.stop(cause: StopCause.silence));
        expect((h.capture.calls.last as CloseCall).cause, StopCause.silence);
      });
    });
  });
}
