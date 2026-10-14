import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/features/recording/data/recording_chunk_writer.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_import.dart';
import 'package:vaultvoice/features/recording/domain/pcm_converter.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';

/// Imports an audio file recorded elsewhere into the same chunked 16 kHz
/// mono layout as a microphone recording (AUD-06), then queues it for the
/// pipeline.
///
/// 1. The caller passes the user's rights/consent attestation time
///    ([importFile]'s `attestedAt`, SEC-09) — there is no way to import
///    without one; it is stored as `recordings.import_attested_at`.
/// 2. Formats the platform cannot decode are refused up front
///    ([ImportFormats]); unknown extensions are left to the decoder.
/// 3. The source is copied into app storage first (`work/import_<id>/`),
///    decoded natively ([AudioDecoder]: AVFoundation / MediaCodec — never a
///    bundled ffmpeg), resampled/down-mixed off the UI isolate when the
///    decoder did not deliver 16 kHz mono, and written through
///    [RecordingChunkWriter] (the [AudioChunkCodec] seam, `audio_chunks`
///    rows).
/// 4. `created_at` = the file's recording date from its metadata, else the
///    date the OS reported for the shared file, else now (filename
///    templates use it).
/// 5. Temporary files are always deleted; a failed import leaves no row.
///
/// Logs only sizes, durations and format ids — never names or paths.
class AudioImportService {
  AudioImportService({
    required this._decoder,
    required RecordingsRepository recordings,
    required this._paths,
    required this._codec,
    required this._clock,
    required this._ids,
    required this.platform,
    required this._enqueue,
    this._disk,
    this._storage = const StoragePolicy(),
    this.chunkDuration = AudioFormat.defaultChunkDuration,
    Logger? logger,
  }) : _repo = recordings,
       _log = logger;

  final AudioDecoder _decoder;
  final RecordingsRepository _repo;
  final StoragePaths _paths;
  final AudioChunkCodec _codec;
  final Clock _clock;
  final IdGenerator _ids;
  final ImportPlatform platform;
  final Future<void> Function(String recordingId) _enqueue;
  final DiskSpaceProbe? _disk;
  final StoragePolicy _storage;
  final Duration chunkDuration;
  final Logger? _log;

  static const _tag = 'import';

  /// Bytes read per chunk-writer append (10 s of contract audio).
  static const int _block = AudioFormat.bytesPerSecond * 10;

  /// Whether [extension] is known to be unsupported on this platform.
  ImportFormat? unsupportedFormat(String? extension) {
    final f = ImportFormats.byExtension(extension);
    return f != null && !f.supportedOn(platform) ? f : null;
  }

  /// Imports [sourcePath]. [extension] overrides the path's extension
  /// (shared files). [deleteSource]: [sourcePath] is a private copy (share
  /// inbox) to remove once copied.
  Future<ImportOutcome> importFile(
    String sourcePath, {
    required DateTime attestedAt,
    String? extension,
    DateTime? sourceDate,
    bool deleteSource = false,
  }) async {
    final ext = (extension ?? p.extension(sourcePath)).replaceFirst('.', '');
    final refused = unsupportedFormat(ext);
    if (refused != null) {
      if (deleteSource) await _delete(File(sourcePath));
      _log?.info(
        _tag,
        'import refused: format',
        fields: {'format': refused.id},
      );
      return ImportUnsupported(refused);
    }
    final source = File(sourcePath);
    if (!source.existsSync()) {
      return const ImportFailed(StorageFailure('import source missing'));
    }
    final id = _ids.next();
    final work = Directory(_paths.workDir('import_$id'));
    try {
      final storage = await _checkStorage(source.lengthSync());
      if (storage != null) return ImportFailed(storage);
      work.createSync(recursive: true);
      final copy = p.join(work.path, ext.isEmpty ? 'source' : 'source.$ext');
      await source.copy(copy);
      if (deleteSource) await _delete(source);
      final decodedPath = p.join(work.path, 'decoded.pcm');
      final decoded = await _decoder.decodeToPcm(copy, decodedPath);
      final DecodedPcm pcm;
      switch (decoded) {
        case Decoded(pcm: final v):
          pcm = v;
        case DecodeRefused(:final error):
          _log?.info(
            _tag,
            'import refused by decoder',
            fields: {'error': error},
          );
          return switch (error) {
            DecodeError.unsupported => ImportUnsupported(
              ImportFormats.byExtension(ext),
            ),
            DecodeError.noAudio => const ImportNoAudio(),
            DecodeError.failed => const ImportFailed(
              UnexpectedFailure('decode failed'),
            ),
          };
      }
      final contractPath = await _toContract(decodedPath, pcm);
      return await _write(
        id,
        contractPath,
        createdAt: pcm.creationDate ?? sourceDate ?? _clock.now(),
        attestedAt: attestedAt,
        format: ImportFormats.byExtension(ext)?.id,
      );
    } on Object catch (e) {
      _log?.error(_tag, 'import failed', fields: {'error': e.runtimeType});
      return ImportFailed(UnexpectedFailure(e.runtimeType.toString()));
    } finally {
      if (work.existsSync()) {
        try {
          work.deleteSync(recursive: true);
        } on FileSystemException {
          // Retried by the next import's cleanup of the work dir root.
        }
      }
    }
  }

  Future<Failure?> _checkStorage(int sourceBytes) async {
    final disk = _disk;
    if (disk == null) return null;
    final free = await disk.freeBytes(_paths.root);
    if (free case Ok(:final value)) {
      // Source copy + decoded PCM + chunks: keep the recording minimum free.
      final after = value - sourceBytes * 2;
      if (_storage.beforeStart(after) == StorageVerdict.refuse) {
        return const StorageFailure('low storage');
      }
    }
    return null;
  }

  /// Resamples/down-mixes off the UI isolate when needed; returns the path
  /// of 16 kHz mono PCM16 LE.
  Future<String> _toContract(String decodedPath, DecodedPcm pcm) async {
    if (pcm.sampleRate == AudioFormat.sampleRate &&
        pcm.channels == AudioFormat.channels) {
      return decodedPath;
    }
    final out = '$decodedPath.16k';
    final rate = pcm.sampleRate;
    final channels = pcm.channels;
    await Isolate.run(
      () => convertPcmFile(decodedPath, out, rate: rate, channels: channels),
    );
    return out;
  }

  Future<ImportOutcome> _write(
    String id,
    String contractPath, {
    required DateTime createdAt,
    required DateTime attestedAt,
    String? format,
  }) async {
    final created = await _repo.create(
      RecordingsCompanion.insert(
        id: id,
        createdAt: createdAt,
        status: RecordingStatus.inProgress,
        source: RecordingSource.imported,
        importAttestedAt: Value(attestedAt),
      ),
    );
    if (created case Err(:final failure)) return ImportFailed(failure);
    final writer = RecordingChunkWriter(
      recordingId: id,
      paths: _paths,
      codec: _codec,
      recordings: _repo,
      chunkDuration: chunkDuration,
    )..beginSegment();
    Failure? failure;
    final raf = await File(contractPath).open();
    try {
      while (true) {
        final bytes = await raf.read(_block);
        if (bytes.isEmpty) break;
        final r = await writer.append(bytes);
        if (r case Err(failure: final f)) {
          failure = f;
          break;
        }
      }
    } finally {
      await raf.close();
    }
    final ended = await writer.endSegment();
    if (ended case Err(failure: final f)) failure ??= f;
    if (failure == null && writer.totalSamples == 0) {
      await _discard(id);
      return const ImportNoAudio();
    }
    if (failure != null) {
      await _discard(id);
      return ImportFailed(failure);
    }
    await _repo.updateFields(
      id,
      RecordingsCompanion(
        status: const Value(RecordingStatus.recorded),
        durationMs: Value(writer.recorded.inMilliseconds),
      ),
    );
    _log?.info(
      _tag,
      'imported',
      fields: {
        'format': format ?? 'unknown',
        'duration_ms': writer.recorded.inMilliseconds,
        'chunks': writer.chunkCount,
      },
    );
    await _enqueue(id);
    return ImportDone(id, writer.recorded);
  }

  Future<void> _discard(String id) async {
    await _repo.deleteById(id);
    final dir = Directory(_paths.audioDir(id));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  static Future<void> _delete(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // Best effort (OS cache dir).
    }
  }
}

/// Streams raw interleaved PCM16 LE at [rate]/[channels] from [src] through
/// the band-limited [PcmConverter] into 16 kHz mono at [dst]. Pure Dart IO —
/// runs inside `Isolate.run`.
void convertPcmFile(
  String src,
  String dst, {
  required int rate,
  required int channels,
}) {
  final converter = PcmConverter(inRate: rate, inChannels: channels);
  final input = File(src).openSync();
  final output = File(dst).openSync(mode: FileMode.write);
  try {
    // Whole frames per read so a frame never splits across blocks.
    final block = 2 * channels * 16384;
    while (true) {
      final bytes = input.readSync(block);
      if (bytes.isEmpty) break;
      output.writeFromSync(converter.convert(Uint8List.fromList(bytes)));
    }
    output.writeFromSync(converter.flush());
  } finally {
    input.closeSync();
    output.closeSync();
  }
}
