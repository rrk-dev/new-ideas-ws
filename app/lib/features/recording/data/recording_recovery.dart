import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';

/// A recording repaired after the app was killed while recording.
final class RecoveredRecording {
  const RecoveredRecording({
    required this.recordingId,
    required this.startedAt,
    required this.duration,
    required this.chunks,
  });

  final String recordingId;

  /// When the recording was started (`recordings.created_at`).
  final DateTime startedAt;

  /// Audio recovered (gaps excluded).
  final Duration duration;

  final int chunks;
}

/// Crash recovery for in-progress recordings (AUD-07, `vv-audio-capture` →
/// Crash recovery).
///
/// A recording whose row is still `recording` or `inProgress` when the app
/// starts was interrupted by a crash, an OS kill or battery death. For each:
/// every chunk file in `audio/<id>/` is repaired through the codec
/// (WAV: sizes rewritten from the file length), `audio_chunks` rows are
/// rebuilt from what is on disk (contiguous start/end ms from the sample
/// counts; missing/empty chunks dropped), and the row becomes `recorded`
/// with `recovered = true`. Recordings with no audio at all are removed.
///
/// Must not run on the recording that is open in this process (`skip`).
class RecordingRecovery {
  RecordingRecovery({
    required this._recordings,
    required this._paths,
    required this._codec,
    Logger? logger,
  }) : _log = logger;

  final RecordingsRepository _recordings;
  final StoragePaths _paths;
  final AudioChunkCodec _codec;
  final Logger? _log;

  static const _tag = 'recording';

  /// Repairs every orphaned recording except those in [skip].
  Future<Result<List<RecoveredRecording>>> recoverOrphans({
    Set<String> skip = const {},
  }) async {
    final orphans = <RecordingRow>[];
    for (final status in [
      RecordingStatus.recording,
      RecordingStatus.inProgress,
    ]) {
      final rows = await _recordings.findByStatus(status);
      if (rows case Err(:final failure)) return Err(failure);
      orphans.addAll(rows.valueOrNull!);
    }
    final out = <RecoveredRecording>[];
    for (final row in orphans) {
      if (skip.contains(row.id)) continue;
      final r = await _recover(row);
      switch (r) {
        case Err(:final failure):
          _log?.error(_tag, 'recovery failed', fields: {'f': failure});
        case Ok(value: final recovered?):
          out.add(recovered);
        case Ok():
          break;
      }
    }
    if (out.isNotEmpty) {
      _log?.info(_tag, 'recordings recovered', fields: {'count': out.length});
    }
    return Ok(out);
  }

  Future<Result<RecoveredRecording?>> _recover(RecordingRow row) async {
    try {
      final dir = Directory(_paths.audioDir(row.id));
      final files = <int, File>{};
      if (dir.existsSync()) {
        final name = RegExp(
          r'^chunk_(\d{4,})\.' + RegExp.escape(_codec.id.extension) + r'$',
        );
        for (final f in dir.listSync().whereType<File>()) {
          final m = name.firstMatch(p.basename(f.path));
          if (m != null) files[int.parse(m.group(1)!)] = f;
        }
      }
      final rows = await _recordings.chunksOf(row.id);
      if (rows case Err(:final failure)) return Err(failure);
      final seqs = {...files.keys, for (final c in rows.valueOrNull!) c.seq}
        ..removeWhere((s) => s < 0);
      final ordered = seqs.toList()..sort();

      var cumulative = 0; // samples
      var kept = 0;
      for (final seq in ordered) {
        final file = files[seq];
        final data = file == null ? 0 : await _codec.recover(file.path);
        if (data == 0) {
          if (file != null && file.existsSync()) await file.delete();
          await _recordings.deleteChunk(row.id, seq);
          continue;
        }
        final samples = data ~/ AudioFormat.bytesPerSample;
        final upsert = await _recordings.upsertChunk(
          AudioChunksCompanion.insert(
            recordingId: row.id,
            seq: seq,
            path: _paths.relativize(file!.path).replaceAll(r'\', '/'),
            sampleRate: AudioFormat.sampleRate,
            startMs: AudioFormat.msOf(cumulative),
            endMs: AudioFormat.msOf(cumulative + samples),
            bytes: file.lengthSync(),
          ),
        );
        if (upsert case Err(:final failure)) return Err(failure);
        cumulative += samples;
        kept++;
      }

      if (kept == 0) {
        // PRODUCT-DECISION: killed before any audio was captured — nothing
        // to recover, so the empty recording is removed.
        await _recordings.deleteById(row.id);
        if (dir.existsSync()) await dir.delete(recursive: true);
        return const Ok(null);
      }
      final duration = AudioFormat.durationOf(cumulative);
      final updated = await _recordings.updateFields(
        row.id,
        RecordingsCompanion(
          status: const Value(RecordingStatus.recorded),
          recovered: const Value(true),
          durationMs: Value(duration.inMilliseconds),
        ),
      );
      if (updated case Err(:final failure)) return Err(failure);
      return Ok(
        RecoveredRecording(
          recordingId: row.id,
          startedAt: row.createdAt,
          duration: duration,
          chunks: kept,
        ),
      );
    } on FileSystemException {
      return const Err(StorageFailure('chunk recovery io failed'));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
