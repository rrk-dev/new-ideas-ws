import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// Short raised-cosine ramps applied where capture starts and stops (start,
/// pause, resume, call interruption) so a segment boundary never produces an
/// audible click when chunks are played or transcribed back to back. Only
/// gain is changed — no sample is added, dropped or duplicated.
abstract final class PcmFade {
  /// Default ramp length (10 ms = 160 samples at 16 kHz).
  static const defaultSamples = AudioFormat.sampleRate ~/ 100;

  /// Ramps the first [samples] mono PCM16 samples of [pcm] up from 0.
  static Uint8List fadeIn(Uint8List pcm, {int samples = defaultSamples}) =>
      _ramp(pcm, samples, fadeIn: true);

  /// Ramps the last [samples] mono PCM16 samples of [pcm] down to 0.
  static Uint8List fadeOut(Uint8List pcm, {int samples = defaultSamples}) =>
      _ramp(pcm, samples, fadeIn: false);

  /// Fade-in for a block that starts [offset] samples into a segment: only
  /// samples whose segment index is below [samples] are ramped.
  static Uint8List fadeInFrom(
    Uint8List pcm, {
    required int offset,
    int samples = defaultSamples,
  }) {
    final out = Uint8List.fromList(pcm);
    final total = out.length ~/ 2;
    final v = ByteData.sublistView(out);
    for (var k = 0; k < total && offset + k < samples; k++) {
      final g = _gain(offset + k, samples);
      final s = v.getInt16(k * 2, Endian.little);
      v.setInt16(k * 2, (s * g).round(), Endian.little);
    }
    return out;
  }

  /// Raised-cosine gain 0 → ~1 at step [k] of [n].
  static double _gain(int k, int n) => 0.5 - 0.5 * math.cos(math.pi * k / n);

  static Uint8List _ramp(Uint8List pcm, int samples, {required bool fadeIn}) {
    final out = Uint8List.fromList(pcm);
    final total = out.length ~/ 2;
    final n = math.min(samples, total);
    if (n <= 0) return out;
    final v = ByteData.sublistView(out);
    for (var k = 0; k < n; k++) {
      final g = _gain(k, n);
      final idx = fadeIn ? k : total - 1 - k;
      final s = v.getInt16(idx * 2, Endian.little);
      v.setInt16(idx * 2, (s * g).round(), Endian.little);
    }
    return out;
  }
}
