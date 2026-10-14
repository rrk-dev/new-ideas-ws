import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' as rec;
import 'package:vaultvoice/features/recording/data/record_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';

class _MockRecorder extends Mock implements rec.AudioRecorder;

void main() {
  setUpAll(() => registerFallbackValue(const rec.RecordConfig()));

  group('buildRecordConfig (recording policy meets the plugin)', () {
    test('PCM16 16 kHz mono stream, voice-recognition source by default', () {
      final c = buildRecordConfig(const MicRequest());
      expect(c.encoder, rec.AudioEncoder.pcm16bits);
      expect(c.sampleRate, 16000);
      expect(c.numChannels, 1);
      expect(
        c.androidConfig.audioSource,
        rec.AndroidAudioSource.voiceRecognition,
      );
      expect(
        buildRecordConfig(const MicRequest(androidSource: MicAudioSource.mic))
            .androidConfig
            .audioSource,
        rec.AndroidAudioSource.mic,
      );
    });

    test('never touches call/VoIP state, never mixes, never auto-resumes', () {
      final c = buildRecordConfig(const MicRequest());
      expect(c.androidConfig.audioManagerMode, rec.AudioManagerMode.modeNormal);
      expect(c.androidConfig.muteAudio, isFalse);
      expect(c.androidConfig.speakerphone, isFalse);
      expect(c.androidConfig.manageBluetooth, isFalse);
      expect(c.audioInterruption, rec.AudioInterruptionMode.pause);
      expect(c.iosConfig.categoryOptions, [
        rec.IosAudioCategoryOption.defaultToSpeaker,
        rec.IosAudioCategoryOption.allowBluetooth,
      ]);
      expect(
        c.iosConfig.categoryOptions,
        isNot(contains(rec.IosAudioCategoryOption.mixWithOthers)),
      );
      expect(c.autoGain || c.echoCancel || c.noiseSuppress, isFalse);
    });

    test('Bluetooth SCO only when the user picked a Bluetooth input', () {
      const bt = AudioInputDevice(
        id: 'bt-1',
        label: 'Headset',
        kind: AudioInputKind.bluetooth,
      );
      final c = buildRecordConfig(const MicRequest(device: bt));
      expect(c.androidConfig.manageBluetooth, isTrue);
      expect(c.device?.id, 'bt-1');
      const wired = AudioInputDevice(
        id: 'w',
        label: 'Wired',
        kind: AudioInputKind.wired,
      );
      expect(
        buildRecordConfig(const MicRequest(device: wired))
            .androidConfig
            .manageBluetooth,
        isFalse,
      );
    });

    test('device types map to input kinds', () {
      expect(inputKindOf(rec.InputDeviceType.builtIn), AudioInputKind.builtIn);
      expect(
        inputKindOf(rec.InputDeviceType.wiredHeadset),
        AudioInputKind.wired,
      );
      expect(
        inputKindOf(rec.InputDeviceType.bluetoothSco),
        AudioInputKind.bluetooth,
      );
      expect(inputKindOf(rec.InputDeviceType.usb), AudioInputKind.usb);
      expect(inputKindOf(rec.InputDeviceType.hdmi), AudioInputKind.unknown);
    });
  });

  group('RecordMicSource', () {
    late _MockRecorder plugin;
    late StreamController<Uint8List> pcm;
    late StreamController<rec.RecordState> states;
    void Function(rec.RecordConfig)? onConfig;
    late int created;

    RecordMicSource source() => RecordMicSource(
      createRecorder: () {
        created++;
        return plugin;
      },
      clock: FakeClock(DateTime.utc(2026)),
    );

    setUp(() {
      created = 0;
      plugin = _MockRecorder();
      pcm = StreamController<Uint8List>();
      states = StreamController<rec.RecordState>();
      when(() => plugin.setOnConfigChanged(any())).thenAnswer((i) async {
        onConfig =
            i.positionalArguments.first as void Function(rec.RecordConfig)?;
      });
      when(() => plugin.onStateChanged()).thenAnswer((_) => states.stream);
      when(() => plugin.startStream(any())).thenAnswer((_) async => pcm.stream);
      when(() => plugin.stop()).thenAnswer((_) async => null);
      when(() => plugin.dispose()).thenAnswer((_) async {});
      when(() => plugin.hasPermission(request: any(named: 'request')))
          .thenAnswer((_) async => true);
      when(() => plugin.listInputDevices()).thenAnswer(
        (_) async => const [
          rec.InputDevice(
            id: 'a',
            label: 'Built-in',
            type: rec.InputDeviceType.builtIn,
          ),
        ],
      );
    });

    test('permission / device queries never start capture', () async {
      final s = source();
      expect(await s.hasPermission(), isTrue);
      final devices = expectOk(await s.inputDevices());
      expect(devices.single.kind, AudioInputKind.builtIn);
      verifyNever(() => plugin.startStream(any()));
      verify(() => plugin.dispose()).called(2);
    });

    test('maps data, format changes, OS pause and errors to MicEvents; '
        'close stops and disposes the plugin', () async {
      final s = source();
      final events = <MicEvent>[];
      expectOk(await s.open(const MicRequest())).listen(events.add);
      final config =
          verify(() => plugin.startStream(captureAny())).captured.single
              as rec.RecordConfig;
      expect(config.sampleRate, 16000);

      onConfig!(const rec.RecordConfig(sampleRate: 48000, numChannels: 1));
      pcm.add(Uint8List(4));
      states.add(rec.RecordState.pause);
      pcm.addError(StateError('boom'));
      await pumpEventQueue();
      expect(events[0], isA<MicFormatChanged>());
      expect((events[0] as MicFormatChanged).format.sampleRate, 48000);
      expect((events[1] as MicData).bytes, hasLength(4));
      expect(events[2], isA<MicInterrupted>());
      expect((events[3] as MicFailed).errorType, 'StateError');

      await s.close();
      verify(() => plugin.stop()).called(1);
      verify(() => plugin.dispose()).called(1);
      expect(created, 1);
      // Nothing is delivered after close.
      expect(pcm.hasListener, isFalse);
    });

    test('a failing start is reported and releases the plugin', () async {
      when(() => plugin.startStream(any())).thenThrow(StateError('busy'));
      final s = source();
      final r = await s.open(const MicRequest());
      expect(r.isOk, isFalse);
      verify(() => plugin.dispose()).called(1);
    });
  });
}
