import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// Name of the APP-02 FTS5 table (`vv-local-database` → FTS5). Cleaned when
/// it exists, so deletion stays correct once search lands.
const kSearchIndexTable = 'search_index';

/// What [RecordingPurger] removes for one recording.
enum PurgeScope {
  /// Everything: rows of every child table, FTS entries, audio, work files
  /// and the rendered note.
  all,

  /// Audio only (retention "Keep audio"): chunk rows, VAD segments, chunk
  /// files and the audio directory. Transcript and note stay.
  audio,

  /// Transcript and notes (retention "Keep transcripts and notes"):
  /// transcripts + segments, speakers, extractions + action items, mind
  /// maps, FTS entries and the rendered note. Audio stays.
  transcripts,
}

/// Secure deletion of one recording's data (SEC-04, `vv-local-database` →
/// Secure deletion).
///
/// Rows (including FTS entries) are deleted in **one transaction** on a
/// connection with `PRAGMA secure_delete = ON`; files are removed after the
/// commit. A crash between the two leaves only unreferenced files, which
/// [sweepOrphans] removes on the next run. The database is sqlite3mc-
/// encrypted and the files are OS-encrypted (ADR-SEC-01), so there is no
/// per-file key to shred; "Delete all data" shreds the database key.
class RecordingPurger {
  RecordingPurger(this.db, this.paths);

  final VaultVoiceDatabase db;
  final StoragePaths paths;

  /// Deletes [scope] of recording [id]. Refuses while a pipeline step is
  /// running for it (cancel the job first); queued/paused/waiting jobs are
  /// deleted with the recording.
  Future<Result<void>> purge(
    String id, {
    PurgeScope scope = PurgeScope.all,
  }) async {
    final found = await guardDb(
      () async => (
        jobs: await (db.select(
          db.jobs,
        )..where((j) => j.recordingId.equals(id))).get(),
        chunks: await (db.select(
          db.audioChunks,
        )..where((c) => c.recordingId.equals(id))).get(),
        hasFts: await _hasTable(kSearchIndexTable),
      ),
    );
    if (found case Err(:final failure)) return Err(failure);
    final (:jobs, :chunks, :hasFts) = found.valueOrNull!;
    if (jobs.any((j) => _active.contains(j.status))) {
      return const Err(StorageFailure('recording is being processed'));
    }
    final rows = await guardDb(() async {
      await db.transaction(() async {
        // APP-02's triggers also maintain the index; deleting explicitly
        // keeps this correct whatever the trigger set. The transcripts scope
        // keeps the `title` row (title + tags of a recording that stays).
        if (scope == PurgeScope.all && hasFts) {
          await db.customStatement(
            'DELETE FROM $kSearchIndexTable WHERE recording_id = ?',
            [id],
          );
        } else if (scope == PurgeScope.transcripts && hasFts) {
          await db.customStatement(
            'DELETE FROM $kSearchIndexTable '
            "WHERE recording_id = ? AND kind <> 'title'",
            [id],
          );
        }
        switch (scope) {
          case PurgeScope.all:
            // Every child table cascades from `recordings` (ADR-FND-04).
            await (db.delete(
              db.recordings,
            )..where((r) => r.id.equals(id))).go();
          case PurgeScope.audio:
            await (db.delete(
              db.audioChunks,
            )..where((c) => c.recordingId.equals(id))).go();
            await (db.delete(
              db.speechSegments,
            )..where((s) => s.recordingId.equals(id))).go();
          case PurgeScope.transcripts:
            await (db.delete(
              db.transcripts,
            )..where((t) => t.recordingId.equals(id))).go();
            await (db.delete(
              db.speakers,
            )..where((s) => s.recordingId.equals(id))).go();
            await (db.delete(
              db.extractions,
            )..where((e) => e.recordingId.equals(id))).go();
            // MAP-01: the mind map is derived from the transcript.
            await (db.delete(
              db.mindMaps,
            )..where((m) => m.recordingId.equals(id))).go();
        }
      });
    });
    if (rows case Err(:final failure)) return Err(failure);
    // Drop the old page images from the WAL too (best effort: a reader may
    // hold it; the next checkpoint finishes the job).
    await guardDb(() => db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)'));
    try {
      if (scope != PurgeScope.transcripts) {
        for (final c in chunks) {
          _deletePath(_resolveOrNull(c.path));
        }
        _deletePath(paths.audioDir(id));
      }
      if (scope != PurgeScope.audio) {
        _deletePath(paths.renderedFile(id));
      }
      if (scope == PurgeScope.all) {
        for (final job in jobs) {
          _deletePath(paths.workDir(job.id));
        }
      }
    } on FileSystemException {
      // Rows are gone; the orphan sweep retries the files.
      return const Err(StorageFailure('could not delete recording files'));
    }
    return const Ok(null);
  }

  /// Removes audio directories, rendered notes and work directories that no
  /// row references any more (left behind by a crash or a failed delete).
  /// Returns the number of entries removed.
  Future<Result<int>> sweepOrphans() async {
    final ids = await guardDb(
      () async => {
        'recordings': (await db.select(db.recordings).get())
            .map((r) => r.id)
            .toSet(),
        'jobs': (await db.select(db.jobs).get()).map((j) => j.id).toSet(),
        // A surviving recording whose chunk / extraction rows were deleted
        // (partial retention) no longer owns its audio / rendered note.
        'audio': (await db.select(db.audioChunks).get())
            .map((c) => c.recordingId)
            .toSet(),
        'capturing': (await db.select(db.recordings).get())
            .where((r) => r.status == RecordingStatus.recording)
            .map((r) => r.id)
            .toSet(),
        'extracted': (await db.select(db.extractions).get())
            .map((e) => e.recordingId)
            .toSet(),
      },
    );
    if (ids case Err(:final failure)) return Err(failure);
    final recordings = ids.valueOrNull!['recordings']!;
    final jobs = ids.valueOrNull!['jobs']!;
    final withAudio = ids.valueOrNull!['audio']!;
    final capturing = ids.valueOrNull!['capturing']!;
    final extracted = ids.valueOrNull!['extracted']!;
    var removed = 0;
    void sweep(String dir, bool Function(String name) keep) {
      final d = Directory(dir);
      if (!d.existsSync()) return;
      for (final e in d.listSync(followLinks: false)) {
        if (keep(p.basename(e.path))) continue;
        _deletePath(e.path);
        removed++;
      }
    }

    try {
      sweep(
        p.join(paths.root, 'audio'),
        (n) =>
            recordings.contains(n) &&
            (withAudio.contains(n) || capturing.contains(n)),
      );
      sweep(
        p.join(paths.root, 'rendered'),
        (n) =>
            n.endsWith('.md') &&
            extracted.contains(n.substring(0, n.length - 3)),
      );
      sweep(p.join(paths.root, 'work'), jobs.contains);
    } on FileSystemException {
      return const Err(StorageFailure('could not sweep orphaned files'));
    }
    return Ok(removed);
  }

  static final Set<String> _active = {
    for (final s in JobState.values)
      if (s.isActive) s.name,
  };

  Future<bool> _hasTable(String name) async {
    final rows = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable.withString(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  String? _resolveOrNull(String relative) {
    // Never delete outside the storage root.
    if (p.isAbsolute(relative)) return null;
    final full = p.normalize(p.join(paths.root, relative));
    return p.isWithin(paths.root, full) ? full : null;
  }

  static void _deletePath(String? path) {
    if (path == null) return;
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      File(path).deleteSync();
    }
  }
}
