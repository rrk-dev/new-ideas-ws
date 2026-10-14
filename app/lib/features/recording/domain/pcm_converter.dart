import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// Streaming PCM16 converter: any input rate / channel count → 16 kHz mono
/// PCM16 (the format contract).
///
/// Used when the platform cannot deliver 16 kHz (Bluetooth HFP at 8 kHz,
/// HALs fixed at 44.1/48 kHz — `record` reports the effective config via
/// `setOnConfigChanged`). Resampling is a proper band-limited polyphase
/// windowed-sinc filter (Blackman window, cutoff just below the lower
/// Nyquist frequency) — never sample dropping/duplication. Channels are
/// down-mixed by averaging.
///
/// Byte boundaries need not align with frames: an incomplete trailing frame
/// is carried over to the next [convert] call.
class PcmConverter {
  PcmConverter({
    required this.inRate,
    required this.inChannels,
    this.outRate = AudioFormat.sampleRate,
    this.zeroCrossings = 16,
  }) : assert(inRate > 0 && inChannels > 0 && outRate > 0, 'invalid format') {
    final g = _gcd(inRate, outRate);
    _up = outRate ~/ g;
    _down = inRate ~/ g;
    if (!isPassthrough) _buildKernel();
  }

  final int inRate;
  final int inChannels;
  final int outRate;

  /// Filter half-length in zero crossings of the (cutoff-scaled) sinc.
  final int zeroCrossings;

  late final int _up; // L
  late final int _down; // M
  late final int _half; // N: taps on each side, in input samples
  late final List<Float64List> _table; // [phase][2N taps]

  Uint8List _carry = Uint8List(0);

  // Mono input history; _buf[0] is absolute input index _bufStart.
  final List<double> _buf = [];
  int _bufStart = 0;
  int _inTotal = 0; // absolute input samples received
  int _outNext = 0; // absolute index of the next output sample

  /// Same rate and mono: bytes are passed through unchanged (frame-aligned).
  bool get isPassthrough => inRate == outRate && inChannels == 1;

  /// Converts the next block of interleaved PCM16 LE [bytes].
  Uint8List convert(Uint8List bytes) {
    final frameBytes = inChannels * 2;
    final joined = _carry.isEmpty
        ? bytes
        : (BytesBuilder(copy: false)
                ..add(_carry)
                ..add(bytes))
              .takeBytes();
    final usable = joined.length - joined.length % frameBytes;
    _carry = Uint8List.fromList(joined.sublist(usable));
    if (usable == 0) return Uint8List(0);
    if (isPassthrough) return Uint8List.fromList(joined.sublist(0, usable));

    final view = ByteData.sublistView(joined, 0, usable);
    final frames = usable ~/ frameBytes;
    for (var f = 0; f < frames; f++) {
      var sum = 0;
      for (var c = 0; c < inChannels; c++) {
        sum += view.getInt16((f * inChannels + c) * 2, Endian.little);
      }
      _buf.add(sum / inChannels);
    }
    _inTotal += frames;
    return _emit(flushing: false);
  }

  /// Emits the remaining output (the filter tail) for the input so far, so
  /// the output length is exactly `inSamples * outRate / inRate`.
  Uint8List flush() {
    _carry = Uint8List(0);
    if (isPassthrough) return Uint8List(0);
    return _emit(flushing: true);
  }

  Uint8List _emit({required bool flushing}) {
    final out = <int>[];
    final target = flushing ? _inTotal * _up ~/ _down : null;
    while (true) {
      if (target != null && _outNext >= target) break;
      final pos = _outNext * _down;
      final i = pos ~/ _up;
      final phase = pos % _up;
      final last = i + _half; // highest input index the taps need
      if (target == null && last >= _inTotal) break;
      final taps = _table[phase];
      var acc = 0.0;
      for (var j = 0; j < taps.length; j++) {
        final idx = i - _half + 1 + j;
        if (idx < 0 || idx >= _inTotal) continue; // zero padding
        acc += _buf[idx - _bufStart] * taps[j];
      }
      out.add(acc.round().clamp(-32768, 32767));
      _outNext++;
    }
    // Drop history no future output needs.
    final keepFrom = (_outNext * _down ~/ _up) - _half + 1;
    final drop = (keepFrom - _bufStart).clamp(0, _buf.length);
    if (drop > 0) {
      _buf.removeRange(0, drop);
      _bufStart += drop;
    }
    final bytes = ByteData(out.length * 2);
    for (var k = 0; k < out.length; k++) {
      bytes.setInt16(k * 2, out[k], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  void _buildKernel() {
    // Cutoff relative to the input rate's Nyquist; 0.92/0.95 leave a
    // transition band so content near the new Nyquist does not alias.
    final ratio = _up / _down;
    final fc = ratio < 1 ? 0.92 * ratio : 0.95;
    _half = (zeroCrossings / fc).ceil();
    _table = List.generate(_up, (p) {
      final taps = Float64List(2 * _half);
      var sum = 0.0;
      for (var j = 0; j < taps.length; j++) {
        final k = j - _half + 1;
        final t = k - p / _up; // input-sample distance to the output instant
        final w = _blackman(t / _half);
        final h = fc * _sinc(fc * t) * w;
        taps[j] = h;
        sum += h;
      }
      // Unity DC gain for every phase (no ripple on constant signals).
      for (var j = 0; j < taps.length; j++) {
        taps[j] /= sum;
      }
      return taps;
    });
  }

  static double _sinc(double x) {
    if (x.abs() < 1e-12) return 1;
    final px = math.pi * x;
    return math.sin(px) / px;
  }

  /// Blackman window on [-1, 1]; 0 outside.
  static double _blackman(double x) {
    if (x.abs() >= 1) return 0;
    final n = (x + 1) / 2; // 0..1
    return 0.42 -
        0.5 * math.cos(2 * math.pi * n) +
        0.08 * math.cos(4 * math.pi * n);
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}
