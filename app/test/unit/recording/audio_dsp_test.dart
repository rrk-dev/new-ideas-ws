import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/pcm_converter.dart';
import 'package:vaultvoice/features/recording/domain/pcm_fade.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';

import '../../fakes/fake_pcm_mic_source.dart';

Uint8List _sine(
  int n,
  double hz,
  int rate, {
  double amp = 0.5,
  int channels = 1,
}) {
  final b = ByteData(n * channels * 2);
  for (var i = 0; i < n; i++) {
    final v = (amp * 32767 * sin(2 * pi * hz * i / rate)).round();
    for (var c = 0; c < channels; c++) {
      b.setInt16((i * channels + c) * 2, v, Endian.little);
    }
  }
  return b.buffer.asUint8List();
}

double _rms(List<int> s) =>
    sqrt(s.fold<double>(0, (a, x) => a + x * x.toDouble()) / s.length);

/// Dominant frequency estimate from zero crossings.
double _zeroCrossingHz(List<int> s, int rate) {
  var crossings = 0;
  for (var i = 1; i < s.length; i++) {
    if ((s[i - 1] < 0) != (s[i] < 0)) crossings++;
  }
  return crossings / 2 / (s.length / rate);
}

void main() {
  group('WavHeader', () {
    test('canonical 44-byte 16 kHz mono PCM16 header round-trips', () {
      final h = WavHeader.build(dataBytes: 32000);
      expect(h.length, 44);
      final info = WavHeader.parse(h)!;
      expect(info.isContractFormat, isTrue);
      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.dataBytes, 32000);
      expect(info.riffSize, 36 + 32000);
    });

    test('recoverable data rounds down to whole samples', () {
      expect(WavHeader.recoverableDataBytes(44), 0);
      expect(WavHeader.recoverableDataBytes(40), 0);
      expect(WavHeader.recoverableDataBytes(44 + 1001), 1000);
      expect(WavHeader.recoverableDataBytes(44 + 1000), 1000);
    });

    test('rejects non-WAV bytes', () {
      expect(WavHeader.parse(Uint8List(44)), isNull);
      expect(WavHeader.parse(Uint8List(10)), isNull);
    });
  });

  group('PcmConverter', () {
    test('16 kHz mono passes through unchanged, carrying odd bytes', () {
      final c = PcmConverter(inRate: 16000, inChannels: 1);
      expect(c.isPassthrough, isTrue);
      final input = Pcm.counter(1000);
      final a = c.convert(Uint8List.sublistView(input, 0, 501));
      final b = c.convert(Uint8List.sublistView(input, 501));
      expect(a.length, 500);
      expect([...a, ...b], input);
    });

    test('48 kHz → 16 kHz keeps a 1 kHz tone, exact length, unity gain', () {
      final c = PcmConverter(inRate: 48000, inChannels: 1);
      final input = _sine(48000, 1000, 48000);
      // Feed in uneven blocks to exercise the streaming state.
      final out = BytesBuilder();
      var o = 0;
      for (final size in [999, 4001, 12000, 31000]) {
        out.add(c.convert(Uint8List.sublistView(input, o, o + size)));
        o += size; // byte sizes, some odd
      }
      out
        ..add(c.convert(Uint8List.sublistView(input, o)))
        ..add(c.flush());
      final s = Pcm.samples(out.takeBytes());
      expect(s.length, 16000);
      final mid = s.sublist(2000, 14000);
      expect(_zeroCrossingHz(mid, 16000), closeTo(1000, 5));
      expect(_rms(mid), closeTo(0.5 * 32767 / sqrt2, 0.5 * 32767 * 0.02));
    });

    test('band-limits: a 10 kHz tone (above the new Nyquist) is removed — '
        'no aliasing from sample dropping', () {
      final c = PcmConverter(inRate: 48000, inChannels: 1);
      final s = Pcm.samples(
        Uint8List.fromList([
          ...c.convert(_sine(48000, 10000, 48000)),
          ...c.flush(),
        ]),
      );
      final mid = s.sublist(2000, 14000);
      const inputRms = 0.5 * 32767 / sqrt2;
      // ≥ 50 dB attenuation.
      expect(_rms(mid) / inputRms, lessThan(pow(10, -50 / 20)));
    });

    test('44.1 kHz stereo → 16 kHz mono (downmix + rational resample)', () {
      final c = PcmConverter(inRate: 44100, inChannels: 2);
      final input = _sine(44100, 440, 44100, channels: 2);
      final out = Pcm.samples(
        Uint8List.fromList([...c.convert(input), ...c.flush()]),
      );
      expect(out.length, 16000);
      expect(_zeroCrossingHz(out.sublist(1000, 15000), 16000), closeTo(440, 3));
    });

    test('8 kHz (Bluetooth HFP) → 16 kHz upsamples to exactly 2×', () {
      final c = PcmConverter(inRate: 8000, inChannels: 1);
      final out = Pcm.samples(
        Uint8List.fromList([
          ...c.convert(_sine(8000, 300, 8000)),
          ...c.flush(),
        ]),
      );
      expect(out.length, 16000);
      expect(_zeroCrossingHz(out.sublist(1000, 15000), 16000), closeTo(300, 3));
    });
  });

  group('PcmFade', () {
    test('fades ramp from/to zero and keep the sample count', () {
      final pcm = Pcm.of(1000, (_) => 20000);
      final faded = Pcm.samples(PcmFade.fadeOut(PcmFade.fadeIn(pcm)));
      expect(faded.length, 1000);
      expect(faded.first, 0);
      expect(faded.last.abs(), lessThan(10));
      expect(faded[500], 20000);
      for (var i = 1; i < PcmFade.defaultSamples; i++) {
        expect(faded[i], greaterThanOrEqualTo(faded[i - 1]));
      }
    });

    test('fadeInFrom continues a ramp across blocks', () {
      final whole = Pcm.samples(PcmFade.fadeIn(Pcm.of(400, (_) => 10000)));
      final a = PcmFade.fadeInFrom(Pcm.of(100, (_) => 10000), offset: 0);
      final b = PcmFade.fadeInFrom(Pcm.of(300, (_) => 10000), offset: 100);
      expect([...Pcm.samples(a), ...Pcm.samples(b)], whole);
    });
  });

  group('StoragePolicy', () {
    const policy = StoragePolicy();
    const mb = StoragePolicy.mb;

    test('refuses to start below 200 MB, warns below 500 MB', () {
      expect(policy.beforeStart(199 * mb), StorageVerdict.refuse);
      expect(policy.beforeStart(200 * mb), StorageVerdict.warn);
      expect(policy.beforeStart(499 * mb), StorageVerdict.warn);
      expect(policy.beforeStart(500 * mb), StorageVerdict.ok);
    });

    test('stops below 100 MB while recording', () {
      expect(policy.whileRecording(99 * mb), StorageVerdict.stop);
      expect(policy.whileRecording(100 * mb), StorageVerdict.warn);
      expect(policy.whileRecording(600 * mb), StorageVerdict.ok);
    });

    test('1 h of the contract format is ~115 MB', () {
      const bytes = AudioFormat.bytesPerSecond * 3600;
      expect(bytes / 1e6, closeTo(115.2, 0.1));
    });
  });
}
