import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// Canonical 44-byte RIFF/WAVE header for PCM16 (`vv-audio-capture` →
/// Format contract). Pure functions so the writer (AUD-01) and crash
/// recovery (AUD-07) share one implementation.
abstract final class WavHeader {
  /// Header length in bytes.
  static const length = 44;

  /// Offset of the RIFF chunk size (`36 + dataBytes`).
  static const riffSizeOffset = 4;

  /// Offset of the `data` chunk size.
  static const dataSizeOffset = 40;

  /// Builds a header for [dataBytes] of PCM16 audio.
  static Uint8List build({
    required int dataBytes,
    int sampleRate = AudioFormat.sampleRate,
    int channels = AudioFormat.channels,
  }) {
    final b = ByteData(length);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    const bitsPerSample = 16;
    final blockAlign = channels * bitsPerSample ~/ 8;
    ascii(0, 'RIFF');
    b.setUint32(riffSizeOffset, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    b
      ..setUint32(16, 16, Endian.little) // fmt chunk size
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * blockAlign, Endian.little) // byte rate
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    b.setUint32(dataSizeOffset, dataBytes, Endian.little);
    return b.buffer.asUint8List();
  }

  /// The two little-endian size fields for [dataBytes]: write `riffSize`
  /// at [riffSizeOffset] and `dataSize` at [dataSizeOffset].
  static ({Uint8List riffSize, Uint8List dataSize}) sizeFields(int dataBytes) {
    Uint8List u32(int v) =>
        (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
    return (riffSize: u32(36 + dataBytes), dataSize: u32(dataBytes));
  }

  /// PCM payload length recoverable from a file of [fileLength] bytes:
  /// everything after the header, rounded down to whole samples (frames).
  static int recoverableDataBytes(
    int fileLength, {
    int channels = AudioFormat.channels,
  }) {
    final frame = channels * AudioFormat.bytesPerSample;
    final data = fileLength - length;
    if (data <= 0) return 0;
    return data - data % frame;
  }

  /// Parses the fields of a canonical header; null when [bytes] is not one.
  static WavInfo? parse(Uint8List bytes) {
    if (bytes.length < length) return null;
    String ascii(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
    if (ascii(0) != 'RIFF' || ascii(8) != 'WAVE' || ascii(12) != 'fmt ') {
      return null;
    }
    if (ascii(36) != 'data') return null;
    final b = ByteData.sublistView(bytes);
    return WavInfo(
      riffSize: b.getUint32(riffSizeOffset, Endian.little),
      format: b.getUint16(20, Endian.little),
      channels: b.getUint16(22, Endian.little),
      sampleRate: b.getUint32(24, Endian.little),
      bitsPerSample: b.getUint16(34, Endian.little),
      dataBytes: b.getUint32(dataSizeOffset, Endian.little),
    );
  }
}

/// Fields of a parsed WAV header.
final class WavInfo {
  const WavInfo({
    required this.riffSize,
    required this.format,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataBytes,
  });

  final int riffSize;
  final int format;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataBytes;

  /// Whether this is the app's contract format (16 kHz mono PCM16) with
  /// consistent size fields.
  bool get isContractFormat =>
      format == 1 &&
      channels == AudioFormat.channels &&
      sampleRate == AudioFormat.sampleRate &&
      bitsPerSample == 16 &&
      riffSize == 36 + dataBytes;
}
