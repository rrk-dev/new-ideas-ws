import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// Something that reports the live input level of an open capture
/// (implemented by `RecordCaptureBackend`; the recording UI listens).
abstract interface class AudioLevelSource {
  Stream<AudioLevel> get levels;
}

/// One meter reading of the live microphone signal (AUD-02).
final class AudioLevel {
  const AudioLevel({
    required this.rmsDbfs,
    required this.peakDbfs,
    this.clipping = false,
  });

  /// Silence (nothing captured yet / paused).
  static const silent = AudioLevel(rmsDbfs: floorDbfs, peakDbfs: floorDbfs);

  /// Lowest level reported; quieter windows are clamped to it.
  static const floorDbfs = -90.0;

  /// RMS of the window, dBFS (≤ 0).
  final double rmsDbfs;

  /// Absolute peak of the window, dBFS (≤ 0).
  final double peakDbfs;

  /// The input clipped within the last second (see [ClipDetector]): show
  /// "move the phone further away".
  final bool clipping;

  /// [rmsDbfs] mapped to 0..1 over [floor]..0 dBFS, for a meter bar.
  double normalized({double floor = -60}) =>
      ((rmsDbfs - floor) / -floor).clamp(0.0, 1.0);

  @override
  String toString() =>
      'AudioLevel(rms ${rmsDbfs.toStringAsFixed(1)}, '
      'peak ${peakDbfs.toStringAsFixed(1)}${clipping ? ', clipping' : ''})';
}

/// Detects input clipping: ≥ [clipRatio] of the samples within the last
/// [window] at `|x| ≥ threshold` (`vv-audio-capture`: 0.5 % at 32 000 in 1 s).
/// Fed the **input** signal (before software gain), in [LevelMeter] window
/// steps, so it tracks a sliding window of sub-window counts.
class ClipDetector {
  ClipDetector({
    this.threshold = 32000,
    this.clipRatio = 0.005,
    this.window = const Duration(seconds: 1),
  });

  final int threshold;
  final double clipRatio;
  final Duration window;

  final _counts = <(int clipped, int total)>[];
  int _clipped = 0;
  int _total = 0;

  /// Counts clipped samples of [pcm] (mono PCM16 LE) — one call per block.
  void add(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    if (n == 0) return;
    final d = ByteData.sublistView(pcm);
    var c = 0;
    for (var i = 0; i < n; i++) {
      if (d.getInt16(i * 2, Endian.little).abs() >= threshold) c++;
    }
    _counts.add((c, n));
    _clipped += c;
    _total += n;
    final max = AudioFormat.samplesFor(window);
    while (_counts.length > 1 && _total - _counts.first.$2 >= max) {
      final (fc, fn) = _counts.removeAt(0);
      _clipped -= fc;
      _total -= fn;
    }
  }

  /// Whether the last [window] clipped.
  bool get clipping => _total > 0 && _clipped / _total >= clipRatio;

  void reset() {
    _counts.clear();
    _clipped = 0;
    _total = 0;
  }
}

/// RMS/peak meter over fixed [window]s (default 50 ms → 20 readings per
/// second of audio, above the ≥ 15 Hz UI requirement). Feed it every block
/// as it is written; it returns one [AudioLevel] per completed window.
///
/// `add(input:)` (optional) is the same block before software gain: clipping
/// is a property of the microphone signal, not of our gain stage.
class LevelMeter {
  LevelMeter({
    this.window = const Duration(milliseconds: 50),
    ClipDetector? clip,
  }) : _windowSamples = AudioFormat.samplesFor(window),
       _clip = clip ?? ClipDetector();

  final Duration window;
  final int _windowSamples;
  final ClipDetector _clip;

  double _sumSq = 0;
  int _peak = 0;
  int _count = 0;

  /// Measures [pcm] (mono PCM16 LE). Returns the readings of every window
  /// completed by this block (possibly none).
  List<AudioLevel> add(Uint8List pcm, {Uint8List? input}) {
    _clip.add(input ?? pcm);
    final n = pcm.length ~/ 2;
    if (n == 0) return const [];
    final d = ByteData.sublistView(pcm);
    final out = <AudioLevel>[];
    for (var i = 0; i < n; i++) {
      final x = d.getInt16(i * 2, Endian.little);
      _sumSq += x.toDouble() * x;
      final a = x.abs();
      if (a > _peak) _peak = a;
      if (++_count == _windowSamples) {
        out.add(_reading());
        _sumSq = 0;
        _peak = 0;
        _count = 0;
      }
    }
    return out;
  }

  AudioLevel _reading() {
    final rms = math.sqrt(_sumSq / _count) / 32768;
    return AudioLevel(
      rmsDbfs: _db(rms),
      peakDbfs: _db(_peak / 32768),
      clipping: _clip.clipping,
    );
  }

  static double _db(double v) {
    if (v <= 0) return AudioLevel.floorDbfs;
    final db = 20 * math.log(v) / math.ln10;
    return db.clamp(AudioLevel.floorDbfs, 0.0);
  }

  /// Starts over (new capture segment).
  void reset() {
    _sumSq = 0;
    _peak = 0;
    _count = 0;
    _clip.reset();
  }
}
