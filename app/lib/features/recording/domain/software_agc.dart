import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// Converts dBFS to a linear amplitude factor (0 dBFS = full scale).
double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

/// Converts a linear amplitude factor to dB (`-inf` for 0).
double linearToDb(double v) =>
    v <= 0 ? double.negativeInfinity : 20 * math.log(v) / math.ln10;

/// Software automatic gain control — the fallback when the platform AGC is
/// unavailable or replaced by the user (AUD-02, `vv-audio-capture` →
/// "Level metering & AGC"):
///
/// * RMS level: exponential mean-square average over [rmsWindow];
/// * gain = [targetDbfs] − envelope, clamped to [[minGainDb], [maxGainDb]];
/// * the applied gain moves down with the [attack] constant and up with the
///   [release] constant (no pumping on short pauses);
/// * a noise gate: below [gateDbfs] the gain is held, so silence is never
///   boosted into audible hiss;
/// * a peak limiter: no output sample exceeds [ceilingDbfs] (−1 dBFS).
///   Where `|x · gain|` would exceed it the gain is cut to exactly fit, and
///   the smoothed gain jumps down with it (instant attack).
///
/// Mono PCM16 LE in, same length out. One instance per capture segment.
class SoftwareAgc {
  SoftwareAgc({
    this.targetDbfs = -20,
    this.maxGainDb = 20,
    this.minGainDb = -12,
    this.ceilingDbfs = -1,
    this.gateDbfs = -60,
    this.attack = const Duration(milliseconds: 10),
    this.release = const Duration(milliseconds: 500),
    this.rmsWindow = const Duration(milliseconds: 50),
    this.sampleRate = AudioFormat.sampleRate,
  }) : assert(maxGainDb >= minGainDb, 'gain range'),
       assert(ceilingDbfs <= 0, 'ceiling at or below full scale'),
       _attackCoef = _coef(attack, sampleRate),
       _releaseCoef = _coef(release, sampleRate),
       _rmsCoef = _coef(rmsWindow, sampleRate),
       _ceiling = dbToLinear(ceilingDbfs) * 32767,
       _maxGain = dbToLinear(maxGainDb),
       _minGain = dbToLinear(minGainDb),
       _target = dbToLinear(targetDbfs),
       _gate = dbToLinear(gateDbfs);

  final double targetDbfs;
  final double maxGainDb;
  final double minGainDb;
  final double ceilingDbfs;
  final double gateDbfs;
  final Duration attack;
  final Duration release;
  final Duration rmsWindow;
  final int sampleRate;

  final double _attackCoef;
  final double _releaseCoef;
  final double _rmsCoef;
  final double _ceiling;
  final double _maxGain;
  final double _minGain;
  final double _target;
  final double _gate;

  /// Mean-square envelope (normalised to full scale = 1).
  double _envelope = 0;

  /// Applied gain (linear). Starts at unity.
  double _gain = 1;

  /// The gain currently applied, in dB.
  double get currentGainDb => linearToDb(_gain);

  static double _coef(Duration d, int rate) {
    final n = d.inMicroseconds * rate / 1e6;
    return n <= 0 ? 1 : 1 - math.exp(-1 / n);
  }

  /// Processes [pcm] and returns the gain-controlled copy.
  Uint8List process(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    final out = Uint8List(n * 2);
    if (n == 0) return out;
    final src = ByteData.sublistView(pcm);
    final dst = ByteData.sublistView(out);
    for (var i = 0; i < n; i++) {
      final x = src.getInt16(i * 2, Endian.little).toDouble();
      final norm = x / 32768;
      final sq = norm * norm;
      _envelope += _rmsCoef * (sq - _envelope);
      final rms = math.sqrt(_envelope);
      if (rms >= _gate) {
        final wanted = (_target / rms).clamp(_minGain, _maxGain);
        _gain +=
            (wanted < _gain ? _attackCoef : _releaseCoef) * (wanted - _gain);
      }
      var g = _gain;
      final mag = x.abs();
      if (mag * g > _ceiling) {
        g = _ceiling / mag;
        _gain = g; // instant attack: following samples stay limited
      }
      var y = (x * g).round();
      // Rounding may land one LSB above the ceiling.
      final c = _ceiling.floor();
      if (y > c) y = c;
      if (y < -c) y = -c;
      dst.setInt16(i * 2, y, Endian.little);
    }
    return out;
  }
}
