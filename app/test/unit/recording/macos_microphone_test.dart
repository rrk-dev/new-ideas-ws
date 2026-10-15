import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/macos_microphone_policy.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';

import '../../db/db_test_utils.dart';
import 'capture_rig.dart';

class _FakeSession implements AudioSessionMonitor {
  final _c = StreamController<AudioSessionEvent>.broadcast(sync: true);

  void emit(
    AudioSessionEventKind kind, {
    String? reason,
    List<String>? inputs,
  }) {
    _c.add(AudioSessionEvent(kind, reason: reason, inputs: inputs ?? const []));
  }

  @override
  Stream<AudioSessionEvent> get events => _c.stream;
}

CaptureRig _macosRig({AudioSessionMonitor? session}) => CaptureRig(
  allowedStarts: macosAllowedStartSources,
  pauseOnInputRemoved: true,
  rejectNonMicrophoneInputs: true,
  audioSession: session ?? const NoAudioSessionMonitor(),
);

const _hostFiles = <String>[
  '../packages/vv_native/macos/Info.plist',
  '../packages/vv_native/macos/DebugProfile.entitlements',
  '../packages/vv_native/macos/Release.entitlements',
  'macos/Runner/MacAudioRouteObserver.swift',
  'lib/features/recording/domain/macos_microphone_policy.dart',
];

const _forbidden = <String>[
  'ScreenCaptureKit',
  'SCStream',
  'SCShareableContent',
  'CGDisplayStream',
  'RPScreenRecorder',
  'AudioHardwareCreateProcessTap',
  'kAudioHardwarePropertyTap',
  'kAudioAggregateDevice',
  'AVCaptureScreen',
  'NSScreenCaptureUsageDescription',
  'com.apple.security.files.downloads.read-write',
  'com.apple.security.files.all',
  'VOICE_CALL',
  'installTap',
  'AVAudioEngine',
  'startStream',
];

void main() {
  test('[AUD-09/AC1] macOS capture cannot start without the Record '
      'button path', () async {
    expect(macosAllowedStartSources, {StartSource.inAppButton});
    expect(StartSource.values.where(macosMayStart).toList(), [
      StartSource.inAppButton,
    ]);
    expect(macosStartSourceFor('recordButton'), StartSource.inAppButton);
    for (final name in macosRefusedStartNames) {
      expect(macosStartSourceFor(name), isNull, reason: name);
    }
    expect(macosMicrophonePurpose, contains('note'));
    expect(macosMicrophonePurpose, contains('not a call'));

    final providers = File(
      'lib/features/recording/data/recording_providers.dart',
    ).readAsStringSync();
    expect(
      providers,
      contains(
        'allowedStarts: Platform.isMacOS ? macosAllowedStartSources : null',
      ),
    );
    final controller = File(
      'lib/features/recording/domain/recording_controller.dart',
    ).readAsStringSync();
    expect(controller, contains('if (!_allowedStarts.contains(source))'));
    expect(
      File('lib/features/recording/domain/macos_microphone_policy.dart')
          .readAsStringSync(),
      isNot(contains('openMicrophone')),
    );

    const aggregate = AudioInputDevice(id: 'agg', label: 'Aggregate');
    const usb = AudioInputDevice(
      id: 'usb-mic',
      label: 'USB microphone',
      kind: AudioInputKind.usb,
    );
    final rig = _macosRig();
    rig.mic.devices = const [aggregate, usb];
    rig.backend.selectInput(aggregate);
    expect(rig.backend.request.device, isNull);
    expect(expectOk(await rig.backend.inputDevices()).map((d) => d.id), [
      'usb-mic',
    ]);

    for (final source in StartSource.values) {
      if (source == StartSource.inAppButton) continue;
      final refused = await rig.controller.start(source);
      expect(
        refused.failureOrNull,
        isA<RecordingBlockedFailure>().having(
          (f) => f.reason,
          'reason',
          RecordingBlockReason.sourceNotAllowed,
        ),
        reason: source.name,
      );
    }
    expect(rig.mic.opens, 0);
    expect(rig.mic.permissionRequests, 0);

    expectOk(await rig.controller.start(StartSource.inAppButton));
    expect(rig.mic.opens, 1);
    expect(rig.mic.requests.single.device, isNull);
    rig.speak(const Duration(seconds: 1));
    await rig.settle();
    final done = expectOk(await rig.controller.stop());
    final id = done.recordingId!;
    final chunk = (await rig.chunks(id)).single;
    final bytes = rig.file(chunk).readAsBytesSync();
    final info = WavHeader.parse(
      Uint8List.sublistView(bytes, 0, WavHeader.length),
    );
    expect(info, isNotNull);
    expect(info!.sampleRate, AudioFormat.sampleRate);
    expect(info.channels, AudioFormat.channels);
    expect(info.bitsPerSample, 16);
    expect(info.isContractFormat, isTrue);
    expect(await rig.recordedSamples(id), isNotEmpty);
  });

  test('macOS permission denial is PermissionFailure and does not open '
      'the microphone', () async {
    final rig = _macosRig()..mic.permission = false;
    final refused = await rig.controller.start(StartSource.inAppButton);
    expect(refused.failureOrNull, isA<PermissionFailure>());
    expect(rig.mic.opens, 0);
    expect(rig.controller.state.phase, RecordingPhase.idle);
  });

  test('unplugging the microphone pauses and nothing auto-resumes', () async {
    final session = _FakeSession();
    final rig = _macosRig(session: session);
    expectOk(await rig.controller.start(StartSource.inAppButton));
    rig.speak(const Duration(seconds: 1));
    await rig.settle();
    session.emit(
      AudioSessionEventKind.routeChanged,
      reason: macosInputRemovedReason,
    );
    await rig.settle();
    expect(rig.controller.state.phase, RecordingPhase.paused);
    expect(rig.controller.state.pauseCause, PauseCause.audioInterruption);
    expect(rig.mic.micOpen, isFalse);
    expect(rig.mic.opens, 1);

    session
      ..emit(AudioSessionEventKind.engineConfigurationChanged)
      ..emit(
        AudioSessionEventKind.routeChanged,
        reason: 'newDeviceAvailable',
        inputs: const ['microphone'],
      );
    await rig.settle();
    expect(rig.controller.state.phase, RecordingPhase.paused);
    expect(rig.mic.opens, 1);

    expectOk(await rig.controller.resume(ResumeSource.inAppButton));
    expect(rig.controller.state.phase, RecordingPhase.recording);
    expect(rig.mic.opens, 2);
    await rig.controller.stop();
  });

  test('[AUD-09/AC3] macOS Info.plist and entitlements request the '
      'microphone only', () {
    final plist = File(_hostFiles[0]).readAsStringSync();
    expect(plist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(plist, contains('<string>$macosMicrophonePurpose</string>'));
    expect(plist, isNot(contains('NSScreenCaptureUsageDescription')));

    const allowedKeys = {
      'com.apple.security.app-sandbox',
      'com.apple.security.device.audio-input',
    };
    for (final path in _hostFiles.skip(1).take(2)) {
      final text = File(path).readAsStringSync();
      final keys = RegExp('<key>([^<]+)</key>')
          .allMatches(text)
          .map((m) => m.group(1)!)
          .toSet();
      expect(keys, allowedKeys, reason: path);
      expect(
        text,
        contains('<key>com.apple.security.device.audio-input</key>'),
      );
    }

    for (final path in _hostFiles) {
      final text = File(path).readAsStringSync();
      for (final token in _forbidden) {
        expect(text, isNot(contains(token)), reason: '$path has $token');
      }
    }
  });

  test('[AUD-09/AC3] the macOS Runner requests the microphone only', () {
    final plist = File('macos/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>$macosMicrophonePurpose</string>'));
    for (final name in ['DebugProfile', 'Release']) {
      final text = File('macos/Runner/$name.entitlements').readAsStringSync();
      final keys = RegExp('<key>([^<]+)</key>')
          .allMatches(text)
          .map((m) => m.group(1)!)
          .toSet();
      expect(keys, contains('com.apple.security.device.audio-input'));
      for (final key in keys) {
        expect(
          key,
          isNot(
            matches(RegExp('screen|camera|temporary-exception|voip|files')),
          ),
          reason: '$name has $key',
        );
      }
    }
    final all = [
      plist,
      File('macos/Runner/AppDelegate.swift').readAsStringSync(),
      File('macos/Runner/MainFlutterWindow.swift').readAsStringSync(),
    ].join();
    for (final token in _forbidden) {
      expect(all, isNot(contains(token)), reason: 'Runner has $token');
    }
  });
}
