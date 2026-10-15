import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/data/platform_audio_effects_probe.dart';
import 'package:vaultvoice/features/recording/data/record_mic_source.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/audio_processing.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/software_agc.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../../fakes/fake_pcm_mic_source.dart';
import '../../fakes/fake_settings_store.dart';
import '../../helpers/test_container.dart';
import 'capture_rig.dart';

/// Sine at [dbfs] peak amplitude, 1 kHz, 16 kHz.
Uint8List tone(int n, double dbfs, {int start = 0, double hz = 1000}) {
  final amp = dbToLinear(dbfs) * 32767;
  return Pcm.of(
    n,
    (i) => (amp * math.sin(2 * math.pi * hz * i / 16000)).round(),
    start: start,
  );
}

double peakDb(Uint8List pcm) {
  var p = 0;
  for (final s in Pcm.samples(pcm)) {
    if (s.abs() > p) p = s.abs();
  }
  return linearToDb(p / 32767);
}

double rmsDb(Uint8List pcm) {
  final s = Pcm.samples(pcm);
  var sum = 0.0;
  for (final x in s) {
    sum += x.toDouble() * x;
  }
  return linearToDb(math.sqrt(sum / s.length) / 32767);
}

/// Runs [seconds] of a [dbfs] tone through [agc] in 20 ms blocks; returns
/// the last block's output.
Uint8List run(SoftwareAgc agc, double seconds, double dbfs) {
  const block = 320;
  final blocks = (seconds * 16000 / block).round();
  var out = Uint8List(0);
  for (var b = 0; b < blocks; b++) {
    out = agc.process(tone(block, dbfs, start: b * block));
  }
  return out;
}

class _Managed implements ManagedSettingsSource {
  const _Managed(this.s);

  final ManagedSettings s;

  @override
  Stream<ManagedSettings> watch() => Stream.value(s);
}

void main() {
  group('software AGC', () {
    test('[AUD-02/AC1] quiet speech is raised towards −20 dBFS RMS but never '
        'by more than the +20 dB gain limit', () {
      final agc = SoftwareAgc();
      // −30 dBFS peak tone ≈ −33 dBFS RMS: needs +13 dB, within the limit.
      final out = run(agc, 3, -30);
      expect(rmsDb(out), closeTo(-20, 1));
      expect(agc.currentGainDb, closeTo(13, 1));

      // −55 dBFS peak tone would need +32 dB: capped at +20 dB.
      final quiet = SoftwareAgc();
      final q = run(quiet, 5, -55);
      expect(quiet.currentGainDb, lessThanOrEqualTo(20.0001));
      expect(quiet.currentGainDb, closeTo(20, 0.5));
      expect(peakDb(q), closeTo(-35, 0.6));
    });

    test('[AUD-02/AC1] loud input is attenuated no further than the minimum '
        'gain', () {
      final agc = SoftwareAgc(minGainDb: -6);
      run(agc, 3, -3);
      expect(agc.currentGainDb, greaterThanOrEqualTo(-6.0001));
      expect(agc.currentGainDb, closeTo(-6, 0.5));
    });

    test('[AUD-02/AC1] limiter: no output sample exceeds −1 dBFS, even for a '
        'sudden full-scale burst after silence at maximum gain', () {
      final agc = SoftwareAgc();
      // Quiet passage drives the gain to +20 dB…
      run(agc, 3, -50);
      expect(agc.currentGainDb, closeTo(20, 0.5));
      // …then a full-scale burst: the limiter must catch the first sample.
      final ceiling = (dbToLinear(-1) * 32767).floor();
      for (var b = 0; b < 50; b++) {
        final out = agc.process(tone(320, 0, start: b * 320));
        for (final s in Pcm.samples(out)) {
          expect(s.abs(), lessThanOrEqualTo(ceiling));
        }
      }
      // Square wave at full scale (worst case for peak limiting).
      final sq = agc.process(Pcm.of(3200, (i) => i.isEven ? 32767 : -32768));
      expect(peakDb(sq), lessThanOrEqualTo(-1.0));
    });

    test('[AUD-02/AC1] silence below the gate is not boosted', () {
      final agc = SoftwareAgc();
      run(agc, 2, -75); // room noise floor
      expect(agc.currentGainDb, closeTo(0, 0.01));
    });

    test('output has the input length (no sample added or dropped)', () {
      final agc = SoftwareAgc();
      expect(agc.process(tone(1234, -20)).length, 1234 * 2);
      expect(agc.process(Uint8List(0)), isEmpty);
    });
  });

  group('processing settings', () {
    const android = PlatformAudioEffects(agc: true, noiseSuppression: true);
    const ios = PlatformAudioEffects(
      agc: true,
      noiseSuppression: true,
      voiceProcessingIo: true,
    );

    test('[AUD-02/AC1] AGC/NS on vs off, software AGC and raw capture '
        'resolve to the right platform flags', () {
      final on = resolveAudioProcessing(
        const AudioProcessingSettings(),
        android,
      );
      expect(
        (on.autoGain, on.noiseSuppress, on.echoCancel, on.softwareAgc),
        (true, true, false, false),
      );
      final off = resolveAudioProcessing(AudioProcessingSettings.none, android);
      expect(
        (off.autoGain, off.noiseSuppress, off.echoCancel, off.softwareAgc),
        (false, false, false, false),
      );
      final sw = resolveAudioProcessing(
        const AudioProcessingSettings(softwareAgc: true),
        android,
      );
      expect((sw.autoGain, sw.softwareAgc), (false, true));
      final raw = resolveAudioProcessing(
        const AudioProcessingSettings(softwareAgc: true, rawCapture: true),
        ios,
      );
      expect(
        (raw.autoGain, raw.noiseSuppress, raw.echoCancel, raw.softwareAgc),
        (false, false, false, false),
      );
    });

    test('[AUD-02/AC1] software AGC is the fallback when the platform has no '
        'AGC', () {
      final r = resolveAudioProcessing(
        const AudioProcessingSettings(),
        const PlatformAudioEffects(agc: false, noiseSuppression: true),
      );
      expect((r.autoGain, r.softwareAgc, r.noiseSuppress), (false, true, true));
    });

    test('iOS: AGC/NS need the voice-processing I/O (record echoCancel)', () {
      final r = resolveAudioProcessing(const AudioProcessingSettings(), ios);
      expect((r.autoGain, r.echoCancel), (true, true));
      final nsOnly = resolveAudioProcessing(
        const AudioProcessingSettings(platformAgc: false),
        ios,
      );
      expect((nsOnly.autoGain, nsOnly.echoCancel), (false, true));
    });

    test('[AUD-02/AC2] provisional default: platform AGC on, software AGC '
        'and raw capture off', () {
      expect(AppSettings.agc.defaultValue, isTrue);
      expect(AppSettings.noiseSuppression.defaultValue, isTrue);
      expect(AppSettings.softwareAgc.defaultValue, isFalse);
      expect(AppSettings.rawCapture.defaultValue, isFalse);
      const d = AudioProcessingSettings();
      expect(
        (d.platformAgc, d.softwareAgc, d.rawCapture),
        (true, false, false),
      );
    });

    test('[AUD-02/AC1] the settings reader applies stored and managed '
        'values', () async {
      final store = FakeSettingsStore({
        AppSettings.agc.key: false,
        AppSettings.rawCapture.key: true,
      });
      final c = createContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          managedSettingsSourceProvider.overrideWithValue(
            _Managed(
              ManagedSettings(values: {AppSettings.softwareAgc.key: true}),
            ),
          ),
        ],
      );
      final read = c.read(audioProcessingSettingsReaderProvider);
      final s = await read();
      expect(
        (s.platformAgc, s.noiseSuppression, s.softwareAgc, s.rawCapture),
        (false, true, true, true),
      );
      await store.set(AppSettings.rawCapture.key, false);
      expect((await read()).rawCapture, isFalse);
    });

    test('record config carries the resolved flags', () {
      const p = ResolvedAudioProcessing(autoGain: true, noiseSuppress: true);
      final cfg = buildRecordConfig(const MicRequest().withProcessing(p));
      expect(
        (cfg.autoGain, cfg.noiseSuppress, cfg.echoCancel),
        (true, true, false),
      );
    });

    test(
      'Android probe reads the effects channel; failure = unavailable',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        const channel = MethodChannel('test/audio_effects');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'audioEffects');
              return {'agc': false, 'noiseSuppression': true};
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final e = await const PlatformAudioEffectsProbe(
          channel: channel,
          isIOS: false,
          isAndroid: true,
        ).probe();
        expect((e.agc, e.noiseSuppression), (false, true));

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async {
              throw PlatformException(code: 'x');
            });
        final failed = await const PlatformAudioEffectsProbe(
          channel: channel,
          isIOS: false,
          isAndroid: true,
        ).probe();
        expect(failed.agc, isFalse);
      },
    );
  });

  group('level meter', () {
    test('[AUD-02/AC3] one reading per 50 ms of audio (20 Hz ≥ 15 Hz) '
        'regardless of the block size', () {
      for (final block in [160, 320, 1024, 4000]) {
        final m = LevelMeter();
        var readings = 0;
        for (var i = 0; i < 16000; i += block) {
          readings += m.add(tone(math.min(block, 16000 - i), -20)).length;
        }
        expect(readings, 20, reason: 'block $block');
      }
    });

    test('RMS and peak in dBFS', () {
      final m = LevelMeter();
      final l = m.add(tone(800, -6)).single;
      expect(l.peakDbfs, closeTo(-6, 0.1));
      expect(l.rmsDbfs, closeTo(-9, 0.2)); // sine: RMS = peak − 3 dB
      expect(m.add(Uint8List(1600)).first.rmsDbfs, AudioLevel.floorDbfs);
      expect(AudioLevel.silent.normalized(), 0);
      expect(
        const AudioLevel(rmsDbfs: -30, peakDbfs: -20).normalized(),
        closeTo(0.5, 1e-9),
      );
    });

    test('[AUD-02/AC1] clipping: ≥ 0.5 % of samples at |x| ≥ 32 000 within '
        '1 s raises the hint, measured on the input before gain', () {
      final m = LevelMeter();
      // 1 s with 0.4 % clipped samples: no hint.
      final few = Pcm.of(16000, (i) => i % 250 == 0 ? 32500 : 1000);
      expect(m.add(few).last.clipping, isFalse);
      // Next second: 1 % clipped → hint.
      final many = Pcm.of(16000, (i) => i % 100 == 0 ? -32700 : 1000);
      expect(m.add(many).last.clipping, isTrue);
      // A clean second later the hint clears (sliding 1 s window).
      expect(m.add(Pcm.of(16000, (_) => 1000)).last.clipping, isFalse);
      // Software gain output does not count — only the raw input does.
      final g = LevelMeter();
      final loudOut = Pcm.of(1600, (_) => 32767);
      final quietIn = Pcm.of(1600, (_) => 3000);
      expect(g.add(loudOut, input: quietIn).last.clipping, isFalse);
    });
  });

  group('capture backend', () {
    test('[AUD-02/AC3] the open capture streams ≥ 15 level readings per '
        'second of audio and goes silent on pause', () async {
      final rig = CaptureRig();
      final levels = <AudioLevel>[];
      final sub = rig.backend.levels.listen(levels.add);
      addTearDown(sub.cancel);
      expect(
        await rig.controller.start(StartSource.inAppButton),
        isA<Object>(),
      );
      rig.speak(
        const Duration(seconds: 2),
        block: const Duration(milliseconds: 20),
        signal: (i) => (8000 * math.sin(i / 3)).round(),
      );
      await rig.settle();
      expect(levels.length, greaterThanOrEqualTo(30));
      expect(levels.length, 40);
      expect(levels.last.rmsDbfs, greaterThan(-20));
      await rig.controller.pause();
      await rig.settle();
      expect(levels.last.rmsDbfs, AudioLevel.floorDbfs);
      await rig.controller.stop();
    });

    test('[AUD-02/AC1] settings switch the platform flags and the software '
        'AGC for the next segment', () async {
      var settings = const AudioProcessingSettings();
      const effects = PlatformAudioEffects(agc: true, noiseSuppression: true);
      final rig = CaptureRig(
        processing: () async => resolveAudioProcessing(settings, effects),
      );
      int quiet(int i) => (300 * math.sin(i / 3)).round();

      await rig.controller.start(StartSource.inAppButton);
      final first = rig.mic.requests.last;
      expect((first.autoGain, first.noiseSuppress), (true, true));
      expect(rig.backend.processing.softwareAgc, isFalse);
      rig.speak(const Duration(seconds: 1), signal: quiet);
      await rig.settle();
      await rig.controller.pause();

      settings = const AudioProcessingSettings(softwareAgc: true);
      await rig.controller.resume(ResumeSource.inAppButton);
      final second = rig.mic.requests.last;
      expect((second.autoGain, second.noiseSuppress), (false, true));
      expect(rig.backend.processing.softwareAgc, isTrue);
      rig.speak(const Duration(seconds: 3), signal: quiet);
      await rig.settle();
      await rig.controller.pause();

      settings = const AudioProcessingSettings(rawCapture: true);
      await rig.controller.resume(ResumeSource.inAppButton);
      final third = rig.mic.requests.last;
      expect(
        (third.autoGain, third.noiseSuppress, third.echoCancel),
        (false, false, false),
      );
      final r = await rig.controller.stop();
      final id = r.valueOrNull!.recordingId!;
      final samples = await rig.recordedSamples(id);
      // Segment 1 untouched (platform AGC does the work); segment 2 boosted
      // by the software AGC (≈ +20 dB on a −40 dBFS signal).
      int peak(Iterable<int> s) => s.map((x) => x.abs()).reduce(math.max);
      expect(peak(samples.take(15000)), lessThanOrEqualTo(300));
      expect(peak(samples.skip(16000 + 30000)), greaterThan(2000));
    });
  });

  test('levels stream closes with the backend', () async {
    final rig = CaptureRig();
    final done = Completer<void>();
    rig.backend.levels.listen(null, onDone: done.complete);
    await rig.backend.dispose();
    await done.future;
  });
}
