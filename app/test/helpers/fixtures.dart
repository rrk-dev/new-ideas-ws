import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:vaultvoice/core/platform/stt_engine.dart';

/// Access to `test/fixtures/` (flutter test runs with the package root as the
/// working directory). Fixtures are synthetic: never commit real recordings.
abstract final class Fixtures {
  static final String root = '${Directory.current.path}/test/fixtures';

  static File file(String relative) {
    final f = File('$root/$relative');
    if (!f.existsSync()) {
      throw StateError('fixture not found: test/fixtures/$relative');
    }
    return f;
  }

  static String readString(String relative) =>
      file(relative).readAsStringSync();

  static Map<String, Object?> readJson(String relative) =>
      jsonDecode(readString(relative)) as Map<String, Object?>;

  /// Loads `transcripts/<name>.json` (`{segments: [{start_ms, end_ms, text}]}`)
  /// as the segments a `FakeSttEngine` should emit.
  static List<TranscriptSegment> transcript(String name) {
    final json = readJson('transcripts/$name.json');
    final segments = json['segments']! as List<Object?>;
    return [
      for (final s in segments.cast<Map<String, Object?>>())
        TranscriptSegment(
          start: Duration(milliseconds: s['start_ms']! as int),
          end: Duration(milliseconds: s['end_ms']! as int),
          text: s['text']! as String,
        ),
    ];
  }
}

/// A deterministic 16 kHz mono PCM16 WAV (sine [frequencyHz], or silence when
/// [frequencyHz] is 0) — the format the recorder and whisper.cpp use. Built in
/// memory so no binary audio has to be committed.
Uint8List synthWav({
  Duration duration = const Duration(seconds: 1),
  double frequencyHz = 440,
  double amplitude = 0.3,
  int sampleRate = 16000,
}) {
  final samples = duration.inMicroseconds * sampleRate ~/ 1000000;
  final dataBytes = samples * 2;
  final b = ByteData(44 + dataBytes);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b
    ..setUint32(16, 16, Endian.little) // fmt chunk size
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little) // byte rate
    ..setUint16(32, 2, Endian.little) // block align
    ..setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples; i++) {
    final v = frequencyHz == 0
        ? 0.0
        : amplitude * sin(2 * pi * frequencyHz * i / sampleRate);
    b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Writes [synthWav] output to `<dir>/<name>` and returns the file.
File writeSynthWav(
  Directory dir,
  String name, {
  Duration duration = const Duration(seconds: 1),
  double frequencyHz = 440,
}) => File('${dir.path}/$name')
  ..writeAsBytesSync(synthWav(duration: duration, frequencyHz: frequencyHz));
