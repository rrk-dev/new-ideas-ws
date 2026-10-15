import 'package:vaultvoice/core/errors/failure.dart';

/// Platforms with a native decoder for imports (AUD-06).
enum ImportPlatform { ios, android }

/// One importable audio format and where the platform decoders handle it
/// (docs/audio-import.md is the user-facing table; keep them in sync — a
/// test checks it).
final class ImportFormat {
  const ImportFormat({
    required this.id,
    required this.extensions,
    required this.ios,
    required this.android,
  });

  /// Stable id, also shown in the "not supported" message (e.g. `Ogg/Opus`).
  final String id;

  /// Lower-case file extensions without the dot.
  final List<String> extensions;

  /// AVFoundation (`AVAssetReader`) decodes it.
  final bool ios;

  /// `MediaExtractor` + `MediaCodec` decode it (API 26+).
  final bool android;

  bool supportedOn(ImportPlatform p) => switch (p) {
    ImportPlatform.ios => ios,
    ImportPlatform.android => android,
  };
}

/// The per-platform format table (AC1). Only native decoders — no ffmpeg.
abstract final class ImportFormats {
  static const all = <ImportFormat>[
    ImportFormat(
      id: 'M4A/AAC',
      extensions: ['m4a', 'aac', 'mp4'],
      ios: true,
      android: true,
    ),
    ImportFormat(id: 'MP3', extensions: ['mp3'], ios: true, android: true),
    ImportFormat(
      id: 'WAV',
      extensions: ['wav', 'wave'],
      ios: true,
      android: true,
    ),
    ImportFormat(id: 'FLAC', extensions: ['flac'], ios: true, android: true),
    ImportFormat(id: 'CAF', extensions: ['caf'], ios: true, android: false),
    ImportFormat(
      id: 'AIFF',
      extensions: ['aif', 'aiff'],
      ios: true,
      android: false,
    ),
    ImportFormat(
      id: 'Ogg/Opus',
      extensions: ['ogg', 'oga', 'opus'],
      ios: false,
      android: true,
    ),
  ];

  /// The format of a file extension (case-insensitive, dot optional).
  static ImportFormat? byExtension(String? ext) {
    if (ext == null) return null;
    final e = ext.toLowerCase().replaceFirst('.', '');
    for (final f in all) {
      if (f.extensions.contains(e)) return f;
    }
    return null;
  }

  /// Every extension a picker should offer on [p].
  static List<String> extensionsFor(ImportPlatform p) => [
    for (final f in all)
      if (f.supportedOn(p)) ...f.extensions,
  ];
}

/// Why the native decoder refused a file.
enum DecodeError {
  /// Container or codec not decodable on this platform.
  unsupported,

  /// The file has no audio track.
  noAudio,

  /// Corrupt file / IO error.
  failed,
}

/// What the native decoder wrote: raw interleaved PCM16 LE.
final class DecodedPcm {
  const DecodedPcm({
    required this.sampleRate,
    required this.channels,
    required this.frames,
    this.creationDate,
  });

  final int sampleRate;
  final int channels;
  final int frames;

  /// Recording date from the file's metadata, if any.
  final DateTime? creationDate;
}

/// Outcome of a native decode.
sealed class DecodeResult {
  const DecodeResult();
}

final class Decoded extends DecodeResult {
  const Decoded(this.pcm);

  final DecodedPcm pcm;
}

final class DecodeRefused extends DecodeResult {
  const DecodeRefused(this.error);

  final DecodeError error;
}

/// Native decoders (iOS AVFoundation, Android MediaCodec) behind a seam.
abstract interface class AudioDecoder {
  /// Decodes [srcPath] into raw PCM16 LE at [dstPath]. Never throws.
  Future<DecodeResult> decodeToPcm(String srcPath, String dstPath);
}

/// Result of importing one file.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// Imported and queued for processing.
final class ImportDone extends ImportOutcome {
  const ImportDone(this.recordingId, this.duration);

  final String recordingId;
  final Duration duration;
}

/// The format cannot be imported on this platform ([format] null = unknown).
final class ImportUnsupported extends ImportOutcome {
  const ImportUnsupported(this.format);

  final ImportFormat? format;
}

/// The file contains no audio.
final class ImportNoAudio extends ImportOutcome {
  const ImportNoAudio();
}

/// Anything else (IO error, corrupt file, low storage).
final class ImportFailed extends ImportOutcome {
  const ImportFailed(this.failure);

  final Failure failure;
}
