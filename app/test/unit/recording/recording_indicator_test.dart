import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/recording/data/method_channel_recording_indicator.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/recording/presentation/battery_guidance.dart';
import 'package:vaultvoice/features/recording/presentation/recording_indicator_binding.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_recording_indicator.dart';
import 'capture_rig.dart';

/// Real capture backend + controller + binding with a fake indicator; the
/// app is backgrounded after the start (screen off / app switched).
class _Background {
  _Background({Duration chunk = const Duration(seconds: 5)})
    : rig = CaptureRig(chunkDuration: chunk) {
    binding = RecordingIndicatorBinding(
      controller: rig.controller,
      indicator: indicator,
      clock: rig.clock,
    );
    addTearDown(binding.dispose);
  }

  final CaptureRig rig;
  final indicator = FakeRecordingIndicator();
  late final RecordingIndicatorBinding binding;

  Future<void> startAndBackground() async {
    expectOk(await rig.controller.start(StartSource.inAppButton));
    await pumpEventQueue();
    rig.foreground = false;
  }

  Future<void> tap(IndicatorAction a) async {
    indicator.tap(a);
    await pumpEventQueue();
    await rig.settle();
  }
}

void main() {
  group('notification content', () {
    final now = DateTime.utc(2026, 10, 13, 10);

    test('recording: chronometer from the recorded time, Pause + Stop', () {
      final c = indicatorContentFor(
        const RecordingState(
          phase: RecordingPhase.recording,
          elapsed: Duration(minutes: 2),
        ),
        now,
      )!;
      expect(c.recording, isTrue);
      expect(c.chronometerBase, now.subtract(const Duration(minutes: 2)));
      expect(c.actions, [IndicatorAction.pause, IndicatorAction.stop]);
    });

    test('[AUD-05/AC3] paused by a call: says the call was not recorded, '
        'offers only Resume (a tap) and Stop', () {
      final c = indicatorContentFor(
        const RecordingState(
          phase: RecordingPhase.paused,
          pauseCause: PauseCause.call,
        ),
        now,
      )!;
      expect(c.recording, isFalse);
      expect(c.title, 'Recording paused because a call started');
      expect(c.text, contains('Audio from the call was not recorded'));
      expect(c.actions, [IndicatorAction.resume, IndicatorAction.stop]);
      expect(c.chronometerBase, isNull);
    });

    test('idle / stopped: no indicator', () {
      for (final p in [RecordingPhase.idle, RecordingPhase.stopped]) {
        expect(indicatorContentFor(RecordingState(phase: p), now), isNull);
      }
    });
  });

  group('background recording', () {
    test('[AUD-05/AC1] a 60-minute recording with the app in the background '
        'keeps capturing without gaps and the indicator stays up', () async {
      final b = _Background(chunk: const Duration(minutes: 5));
      await b.startAndBackground();
      await b.rig.speakPaced(const Duration(minutes: 60), silent: true);
      expect(b.rig.controller.state.phase, RecordingPhase.recording);
      expect(b.indicator.visible, isTrue);
      expect(b.indicator.hides, 0);
      final done = expectOk(await b.rig.controller.stop());
      expect(done.duration, const Duration(minutes: 60));
      final chunks = await b.rig.chunks(done.recordingId!);
      expect(chunks, hasLength(12));
      for (var i = 0; i < chunks.length; i++) {
        expect(
          (chunks[i].startMs, chunks[i].endMs),
          (i * 300000, (i + 1) * 300000),
        );
      }
      expect(await b.rig.markers(done.recordingId!), isEmpty, reason: 'no gap');
      await pumpEventQueue();
      expect(b.indicator.visible, isFalse);
    });

    test('[AUD-05/AC2] notification Pause / Resume / Stop drive the '
        'recording while the app is in the background', () async {
      final b = _Background();
      await b.startAndBackground();
      expect(b.indicator.current!.recording, isTrue);
      b.rig.speak(const Duration(seconds: 2));

      await b.tap(IndicatorAction.pause);
      expect(b.rig.controller.state.phase, RecordingPhase.paused);
      expect(b.rig.mic.micOpen, isFalse);
      expect(b.indicator.current!.actions, contains(IndicatorAction.resume));

      // Resume from the notification works while backgrounded (it is a tap).
      await b.tap(IndicatorAction.resume);
      expect(b.rig.controller.state.phase, RecordingPhase.recording);
      expect(b.rig.mic.opens, 2);
      b.rig.speak(const Duration(seconds: 1));

      await b.tap(IndicatorAction.stop);
      expect(b.rig.controller.state.phase, RecordingPhase.stopped);
      expect(b.indicator.visible, isFalse);
      expect(b.indicator.hides, 1);
      // The tap's stop() finalizes asynchronously.
      var rows = await b.rig.db.recordingsRepository.watchAll().first;
      for (var i = 0; i < 100 && rows.single.status.name != 'recorded'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        rows = await b.rig.db.recordingsRepository.watchAll().first;
      }
      expect(rows.single.status.name, 'recorded');
      expect(rows.single.durationMs, 3000);
    });

    test(
      '[AUD-05/AC3] a call while recording in the background: no call '
      'audio, stays paused after hang-up until the user taps Resume',
      () async {
        final b = _Background();
        await b.startAndBackground();
        b.rig.speak(const Duration(seconds: 3));
        final id = b.rig.backend.recordingId!;
        b.rig.guard.emit(CallGuardSignal.callActive, b.rig.clock.now());
        if (b.rig.mic.micOpen) b.rig.speak(const Duration(milliseconds: 300));
        await b.rig.settle();
        await pumpEventQueue();
        expect(b.rig.controller.state.pauseCause, PauseCause.call);
        expect(b.indicator.current!.title, contains('call started'));
        // 3000 − 250 ms safety margin; nothing from after the event.
        expect(
          await b.rig.recordedSamples(id),
          hasLength(16000 * 2750 ~/ 1000),
        );

        // Resume tapped while the call is still active: refused, stays paused.
        await b.tap(IndicatorAction.resume);
        expect(b.rig.controller.state.phase, RecordingPhase.paused);
        expect(b.rig.mic.opens, 1);

        b.rig.guard.emit(CallGuardSignal.callEnded, b.rig.clock.now());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(b.rig.controller.state.phase, RecordingPhase.paused);
        expect(b.rig.mic.opens, 1, reason: 'never auto-resumed');

        await b.tap(IndicatorAction.resume);
        expect(b.rig.controller.state.phase, RecordingPhase.recording);
        await b.rig.controller.stop();
      },
    );

    test('the "Still recording" reminder goes to the indicator', () {
      final indicator = FakeRecordingIndicator()
        ..stillRecording(const Duration(hours: 1));
      expect(indicator.reminders, [const Duration(hours: 1)]);
    });
  });

  group('platform channel', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(
      MethodChannelRecordingIndicator.methodChannelName,
    );
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            calls.add(c);
            if (c.method == 'batteryStatus') {
              return {
                'manufacturer': 'Samsung',
                'ignoringOptimizations': false,
              };
            }
            if (c.method == 'show' && (c.arguments as Map)['title'] == 'x') {
              throw PlatformException(code: 'fgs_refused');
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('encodes show / remind / hide and maps refusals to Err', () async {
      final ind = MethodChannelRecordingIndicator();
      final base = DateTime.utc(2026);
      expectOk(
        await ind.show(
          IndicatorContent(
            recording: true,
            title: 'Recording',
            text: 't',
            chronometerBase: base,
            actions: const [IndicatorAction.pause, IndicatorAction.stop],
          ),
        ),
      );
      ind.stillRecording(const Duration(minutes: 61));
      await ind.hide();
      await pumpEventQueue();
      expect(calls.map((c) => c.method), ['show', 'remind', 'hide']);
      expect(calls[0].arguments, {
        'recording': true,
        'title': 'Recording',
        'text': 't',
        'chronometerBaseMs': base.millisecondsSinceEpoch,
        'actions': ['pause', 'stop'],
      });
      expect(calls[1].arguments, {'text': 'Still recording (1h 01m)'});
      final refused = await ind.show(
        const IndicatorContent(
          recording: true,
          title: 'x',
          text: '',
          actions: [],
        ),
      );
      expect(refused.isOk, isFalse);
      final battery = (await ind.batteryStatus())!;
      expect(battery.manufacturer, 'samsung');
      expect(batteryGuidanceText(battery), contains('Never sleeping apps'));
    });
  });

  group('battery guidance', () {
    test('only for aggressive OEMs that are not exempt', () {
      String? g(String oem, {bool exempt = false}) => batteryGuidanceText(
        BatteryStatus(manufacturer: oem, ignoringOptimizations: exempt),
      );
      expect(g('google'), isNull);
      expect(g('samsung', exempt: true), isNull);
      expect(g('xiaomi'), contains('Autostart'));
      expect(g('oneplus'), contains('Allow background activity'));
      expect(g('huawei'), contains('run in the background'));
      expect(batteryGuidanceText(null), isNull);
    });
  });

  group('Play policy: foreground service declaration', () {
    // Lazy: read inside the test so tag-filtered runs without android/ (the
    // Linux golden container) can still load this file.
    late final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    late final service = File(
      'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/'
      'RecordingService.kt',
    ).readAsStringSync();

    test('[AUD-05/AC4] one microphone-type FGS, its permissions, no other '
        'FGS types, no battery-optimization exemption request', () {
      final services = RegExp(
        r'<service\b[^>]*>',
        dotAll: true,
      ).allMatches(manifest).map((m) => m.group(0)!).toList();
      // Integration wave 2: MDL-02 adds ModelDownloadService (type dataSync,
      // no microphone access). The recording FGS stays the only microphone
      // service; no other FGS type may appear.
      expect(services, hasLength(2));
      final recording = services.singleWhere(
        (s) => s.contains('android:name=".RecordingService"'),
      );
      expect(recording, contains('android:foregroundServiceType="microphone"'));
      expect(recording, contains('android:exported="false"'));
      final download = services.singleWhere(
        (s) => s.contains('android:name=".modeldownload.ModelDownloadService"'),
      );
      expect(download, contains('android:foregroundServiceType="dataSync"'));
      expect(download, contains('android:exported="false"'));
      expect(services.where((s) => s.contains('"microphone"')), hasLength(1));
      for (final p in [
        'RECORD_AUDIO',
        'FOREGROUND_SERVICE',
        'FOREGROUND_SERVICE_MICROPHONE',
        'POST_NOTIFICATIONS',
      ]) {
        expect(manifest, contains('android.permission.$p"'), reason: p);
      }
      final fgsPermissions = RegExp(
        r'android\.permission\.(FOREGROUND_SERVICE_\w+)',
      ).allMatches(manifest).map((m) => m.group(1)).toSet();
      expect(fgsPermissions, {
        'FOREGROUND_SERVICE_MICROPHONE',
        'FOREGROUND_SERVICE_DATA_SYNC', // MDL-02 model downloads
      });
      expect(manifest, isNot(contains('REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')));
      expect(service, contains('FOREGROUND_SERVICE_TYPE_MICROPHONE'));
      expect(service, contains('START_NOT_STICKY'));
      expect(service, isNot(contains('START_STICKY ')));
    });
  });
}
