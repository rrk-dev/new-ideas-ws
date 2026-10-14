import 'dart:io';

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';

/// What a deletion did to the exported notes.
class RecordingDeletion {
  const RecordingDeletion({
    required this.notesDeleted,
    required this.notesKept,
  });

  /// Exported notes removed from vault folders.
  final int notesDeleted;

  /// Exported notes left in place (not requested, or the folder could not
  /// be reached — the user can delete those by hand).
  final int notesKept;
}

/// Deletes a recording (APP-02): optionally its exported notes first, then
/// every DB row (child tables cascade; the FTS triggers drop the search rows)
/// in one transaction, then its files — audio, job work dirs and the
/// rendered note. SEC-04's secure purger can replace it behind the provider.
abstract interface class RecordingDeleter {
  Future<Result<RecordingDeletion>> delete(
    String recordingId, {
    required bool deleteExportedNotes,
  });
}

/// Writer for a vault target row, or null when the folder is unreachable.
typedef VaultWriterForTarget = VaultWriter? Function(VaultTargetRow target);

class LocalRecordingDeleter implements RecordingDeleter {
  LocalRecordingDeleter({
    required this._db,
    required this._paths,
    required this._writerFor,
    required this._stopJobs,
  });

  final VaultVoiceDatabase _db;
  final StoragePaths _paths;
  final VaultWriterForTarget _writerFor;

  /// Cancels the recording's jobs still in the pipeline (so no step writes
  /// outputs for a recording that no longer exists).
  final Future<void> Function(List<String> jobIds) _stopJobs;

  @override
  Future<Result<RecordingDeletion>> delete(
    String recordingId, {
    required bool deleteExportedNotes,
  }) async {
    final found = await guardDb(
      () async => (
        exports: await (_db.select(
          _db.exports,
        )..where((e) => e.recordingId.equals(recordingId))).get(),
        jobs: await (_db.select(
          _db.jobs,
        )..where((j) => j.recordingId.equals(recordingId))).get(),
        extractions: await (_db.select(
          _db.extractions,
        )..where((e) => e.recordingId.equals(recordingId))).get(),
      ),
    );
    if (found case Err(:final failure)) return Err(failure);
    final (:exports, :jobs, :extractions) = found.valueOrNull!;

    var deleted = 0;
    var kept = 0;
    for (final e in exports) {
      if (e.status != ExportStatus.written) continue;
      if (!deleteExportedNotes) {
        kept++;
        continue;
      }
      final target = (await _db.vaultRepository.getTarget(e.targetId))
          .valueOrNull;
      final writer = target == null ? null : _writerFor(target);
      final removed = writer == null ? null : await writer.delete(e.relPath);
      if (removed != null && removed.isOk) {
        deleted++;
      } else {
        kept++;
      }
    }

    await _stopJobs([for (final j in jobs) j.id]);
    final rows = await guardDb(
      () => _db.transaction(() async {
        await _db.customStatement(
          'DELETE FROM search_index WHERE recording_id = ?',
          [recordingId],
        );
        await (_db.delete(
          _db.recordings,
        )..where((r) => r.id.equals(recordingId))).go();
        // APP-05 review approvals of its extractions.
        for (final e in extractions) {
          await _db.settingsRepository.remove(ReviewKeys.approved(e.id));
        }
      }),
    );
    if (rows case Err(:final failure)) return Err(failure);

    await _deleteQuietly(Directory(_paths.audioDir(recordingId)));
    for (final j in jobs) {
      await _deleteQuietly(Directory(_paths.workDir(j.id)));
    }
    await _deleteQuietly(File(_paths.renderedFile(recordingId)));
    return Ok(RecordingDeletion(notesDeleted: deleted, notesKept: kept));
  }

  static Future<void> _deleteQuietly(FileSystemEntity e) async {
    try {
      if (e.existsSync()) await e.delete(recursive: true);
    } on FileSystemException {
      // Left for SEC-04's orphan sweep; the rows are already gone.
    }
  }
}
