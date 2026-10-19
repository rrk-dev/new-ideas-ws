import 'dart:io';
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/wav_header.dart';

/// True when the PCM16 WAV at [path] holds nothing but (near) zeros: an
/// input that delivered no signal (wrong microphone, closed laptop lid).
/// Whisper invents text ("Thank you") on such audio, so it is not
/// transcribed. Unreadable files are treated as not silent.
Future<bool> isDigitalSilence(String path, {int maxAbsSample = 2}) async {
  try {
    final bytes = await File(path).readAsBytes();
    if (bytes.length <= WavHeader.length) return false;
    final data = ByteData.sublistView(bytes);
    for (var i = WavHeader.length; i + 1 < bytes.length; i += 2) {
      if (data.getInt16(i, Endian.little).abs() > maxAbsSample) return false;
    }
    return true;
  } on Object {
    return false;
  }
}
