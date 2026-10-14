import 'dart:io';

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';
import 'package:vaultvoice/features/retention/domain/retention_policy.dart';

/// Counts of one [RetentionSweeper.run] (no ids, no content: loggable).
class RetentionReport {
  const RetentionReport({
    this.recordingsDeleted = 0,
    this.audioDeleted = 0,
    this.transcriptsDeleted = 0,
    this.orphansRemoved = 0,
    this.skippedBusy = 0,
    this.failures = 0,
  });

  final int recordingsDeleted;
  final int audioDeleted;
  final int transcriptsDeleted;
  final int orphansRemoved;
  final int skippedBusy;
  final int failures;

  Map<String, Object> toLogFields() => {
    'recordings': recordingsDeleted,
    'audio': audioDeleted,
    'transcripts': transcriptsDeleted,
    'orphans': orphansRemoved,
    'busy': skippedBusy,
    'failures': failures,
  };
}

/// Applies the retention settings (SEC-04) to every finished recording.
///
/// - Recordings still being captured (`recording` / `inProgress`) and
///   recordings with an unfinished pipeline job are skipped.
/// - Audio due → chunk rows + files deleted, transcript/note kept.
/// - Transcripts due → transcript, speakers, extraction, action items, FTS
///   rows and the rendered note deleted, audio kept.
/// - Both due → the whole recording is deleted.
///   PRODUCT-DECISION: a recording without audio and transcript has nothing
///   left to show, so its row goes too.
class RetentionSweeper {
  RetentionSweeper({
    required this.db,
    required this.paths,
    required this.purger,
    required this.policyFor,
    this.clock = const SystemClock(),
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final RecordingPurger purger;

  /// Effective retention option of a setting key (managed › user › default).
  final Future<RetentionPolicy> Function(String settingKey) policyFor;
  final Clock clock;

  static final Set<String> _terminal = {
    for (final s in JobState.values)
      if (s.isTerminal) s.name,
  };

  Future<Result<RetentionReport>> run({
    required String audioKey,
    required String transcriptKey,
  }) async {
    final audio = await policyFor(audioKey);
    final transcripts = await policyFor(transcriptKey);
    final now = clock.now();
    final state = await guardDb(
      () async => (
        recordings:
            await (db.select(db.recordings)..where(
                  (r) => r.status.isInValues([
                    RecordingStatus.recorded,
                    RecordingStatus.failed,
                  ]),
                ))
                .get(),
        jobs: await db.select(db.jobs).get(),
        exports: await (db.select(
          db.exports,
        )..where((e) => e.status.equalsValue(ExportStatus.written))).get(),
        chunks: await db.select(db.audioChunks).get(),
        transcripts: await db.select(db.transcripts).get(),
        extractions: await db.select(db.extractions).get(),
      ),
    );
    if (state case Err(:final failure)) return Err(failure);
    final s = state.valueOrNull!;
    final busy = {
      for (final j in s.jobs)
        if (!_terminal.contains(j.status)) j.recordingId,
    };
    final exported = {for (final e in s.exports) e.recordingId};
    final withAudio = {for (final c in s.chunks) c.recordingId};
    final withText = {
      for (final t in s.transcripts) t.recordingId,
      for (final e in s.extractions) e.recordingId,
    };

    var recordings = 0;
    var audioDeleted = 0;
    var textDeleted = 0;
    var skipped = 0;
    var failures = 0;
    for (final r in s.recordings) {
      bool due(RetentionPolicy p) => p.isDue(
        createdAt: r.createdAt,
        now: now,
        exported: exported.contains(r.id),
      );
      final audioDue = due(audio);
      final textDue = due(transcripts);
      if (!audioDue && !textDue) continue;
      if (busy.contains(r.id)) {
        skipped++;
        continue;
      }
      final hasAudio = withAudio.contains(r.id);
      final hasText =
          withText.contains(r.id) ||
          File(paths.renderedFile(r.id)).existsSync();
      final PurgeScope scope;
      if (audioDue && textDue) {
        scope = PurgeScope.all;
      } else if (audioDue && hasAudio) {
        scope = PurgeScope.audio;
      } else if (textDue && hasText) {
        scope = PurgeScope.transcripts;
      } else {
        continue;
      }
      switch (await purger.purge(r.id, scope: scope)) {
        case Ok():
          switch (scope) {
            case PurgeScope.all:
              recordings++;
            case PurgeScope.audio:
              audioDeleted++;
            case PurgeScope.transcripts:
              textDeleted++;
          }
        case Err():
          failures++;
      }
    }
    final orphans = await purger.sweepOrphans();
    if (orphans case Err()) failures++;
    return Ok(
      RetentionReport(
        recordingsDeleted: recordings,
        audioDeleted: audioDeleted,
        transcriptsDeleted: textDeleted,
        orphansRemoved: orphans.valueOrNull ?? 0,
        skippedBusy: skipped,
        failures: failures,
      ),
    );
  }
}
