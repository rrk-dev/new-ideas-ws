import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/recording/data/method_channel_audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import '../../db/db_test_utils.dart';
import 'capture_rig.dart';

class _FakeSession implements AudioSessionMonitor {
  final _c = StreamController<AudioSessionEvent>.broadcast(sync: true);

  bool get listening => _c.hasListener;

  void emit(AudioSessionEventKind kind, {String? reason}) =>
      _c.add(AudioSessionEvent(kind, reason: reason, inputs: const ['x']));

  @override
  Stream<AudioSessionEvent> get events => _c.stream;
}

const _ms = Duration(milliseconds: 1);

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue);
}

/// iOS-shaped rig: the app goes to the background right after the start.
Future<(CaptureRig, _FakeSession, List<RecordingPhase>)> _backgrounded({
  Duration chunk = const Duration(seconds: 5),
}) async {
  final session = _FakeSession();
  final rig = CaptureRig(chunkDuration: chunk, audioSession: session);
  final phases = <RecordingPhase>[];
  rig.controller.states.listen((s) => phases.add(s.phase));
  expectOk(await rig.controller.start(StartSource.inAppButton));
  rig.foreground = false;
  return (rig, session, phases);
}

void main() {
  test('[AUD-04/AC1] a 60-minute recording with the app in the background / '
      'device locked completes without loss', () async {
    final (rig, session, phases) = await _backgrounded(
      chunk: const Duration(minutes: 5),
    );
    expect(session.listening, isTrue);
    await rig.speakPaced(const Duration(minutes: 60), silent: true);
    final done = expectOk(await rig.controller.stop());
    expect(done.duration, const Duration(minutes: 60));
    expect(await rig.chunks(done.recordingId!), hasLength(12));
    expect(phases, isNot(contains(RecordingPhase.paused)));
    expect(session.listening, isFalse, reason: 'observers only while open');
  });

  test('[AUD-04/AC2] an incoming call while backgrounded stops capture at '
      'once, keeps no call audio, marks the gap and stays paused after the '
      'call (no auto-resume on interruption end)', () async {
    final (rig, _, _) = await _backgrounded();
    rig.speak(const Duration(seconds: 2));
    final id = rig.backend.recordingId!;
    // CXCallObserver: ringing.
    rig.guard.emit(CallGuardSignal.callActive, rig.clock.now());
    expect(rig.controller.state.phase, RecordingPhase.paused);
    // Audio session interruption begins as the call is answered.
    rig.guard.emit(CallGuardSignal.interruptionBegan, rig.clock.now());
    if (rig.mic.micOpen) rig.speak(const Duration(milliseconds: 200));
    await rig.settle();
    expect(rig.mic.micOpen, isFalse);
    expect(
      await rig.recordedSamples(id),
      hasLength(AudioFormat.samplesFor(const Duration(milliseconds: 1000))),
    );
    final marker = (await rig.markers(id)).single;
    expect(marker.kind, MarkerKind.callInterruption);
    // Call ends; iOS reports interruption ended (with .shouldResume) — the
    // recording must stay paused.
    rig.guard
      ..emit(CallGuardSignal.interruptionEnded, rig.clock.now())
      ..emit(CallGuardSignal.callEnded, rig.clock.now());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(rig.controller.state.phase, RecordingPhase.paused);
    expect(rig.mic.opens, 1);
    await rig.controller.stop();
  });

  group('[AUD-04/AC3] route changes', () {
    test('[AUD-04/AC3] connecting a Bluetooth headset mid-recording '
        '(engine configuration change) does not stop the recording', () async {
      final (rig, session, phases) = await _backgrounded();
      rig.speak(const Duration(seconds: 1));
      session.emit(
        AudioSessionEventKind.routeChanged,
        reason: 'newDeviceAvailable',
      );
      await pumpEventQueue();
      expect(rig.mic.opens, 1, reason: 'a plain route change keeps going');
      session.emit(AudioSessionEventKind.engineConfigurationChanged);
      await _until(() => rig.mic.opens == 2 && rig.mic.micOpen);
      expect(rig.controller.state.phase, RecordingPhase.recording);
      expect(phases, isNot(contains(RecordingPhase.paused)));
      rig.speak(const Duration(seconds: 1));
      final done = expectOk(await rig.controller.stop());
      final id = done.recordingId!;
      expect(
        [for (final c in await rig.chunks(id)) (c.startMs, c.endMs)],
        [(0, 1000), (1000, 2000)],
      );
      final marker = (await rig.markers(id)).single;
      expect(marker.label, 'route_change');
      expect(marker.atMs, 1000);
      expect(done.duration, const Duration(seconds: 2));
    });

    test('[AUD-04/AC3] a media-services reset rebuilds the input and '
        'continues in a new chunk', () async {
      final (rig, session, _) = await _backgrounded();
      rig.speak(_ms * 500);
      session.emit(AudioSessionEventKind.mediaServicesReset);
      await _until(() => rig.mic.opens == 2 && rig.mic.micOpen);
      expect(rig.controller.state.phase, RecordingPhase.recording);
      rig.speak(_ms * 500);
      final done = expectOk(await rig.controller.stop());
      expect(await rig.chunks(done.recordingId!), hasLength(2));
    });

    test('the input is never reopened during a call: it pauses instead '
        '(fail closed)', () async {
      final (rig, session, _) = await _backgrounded();
      rig.speak(_ms * 500);
      rig.guard.inCall = true; // e.g. call routed before CallKit reported it
      session.emit(AudioSessionEventKind.engineConfigurationChanged);
      await _until(() => rig.controller.state.phase == RecordingPhase.paused);
      expect(rig.controller.state.pauseCause, PauseCause.call);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rig.mic.opens, 1);
      expect(rig.mic.micOpen, isFalse);
      await rig.controller.stop();
    });

    test('a paused recording is never reopened by a route change', () async {
      final (rig, session, _) = await _backgrounded();
      rig.speak(_ms * 300);
      expectOk(await rig.controller.pause());
      session.emit(AudioSessionEventKind.engineConfigurationChanged);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rig.mic.opens, 1);
      expect(rig.controller.state.phase, RecordingPhase.paused);
      await rig.controller.stop();
    });
  });

  test('audio-session events decode from the platform wire format', () {
    final e = MethodChannelAudioSessionMonitor.decode({
      'kind': 'routeChanged',
      'reason': 'oldDeviceUnavailable',
      'inputs': ['MicrophoneBuiltIn', 3],
    })!;
    expect(e.kind, AudioSessionEventKind.routeChanged);
    expect(e.reason, 'oldDeviceUnavailable');
    expect(e.inputs, ['MicrophoneBuiltIn']);
    expect(MethodChannelAudioSessionMonitor.decode({'kind': 'nope'}), isNull);
    expect(MethodChannelAudioSessionMonitor.decode('x'), isNull);
  });
}
