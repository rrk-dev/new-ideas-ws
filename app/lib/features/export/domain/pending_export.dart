import 'package:flutter/foundation.dart' show immutable;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// Why a note has not reached its vault folder yet (EXP-06).
enum PendingReason {
  /// No vault folder is configured: pick one or save on this device.
  noDestination,

  /// The folder grant was revoked / the folder moved: re-grant or change.
  accessRevoked,

  /// The folder is temporarily unreachable (SD card, iCloud, disk full);
  /// the pipeline retries with backoff.
  retrying,

  /// Automatic retries are exhausted: retry by hand or change the folder.
  failed,
}

/// One entry of the "Pending exports" list. The rendered note is safe in
/// app storage (`rendered/<id>.md`); only the vault write is outstanding.
@immutable
class PendingExport {
  const PendingExport({
    required this.recordingId,
    required this.title,
    required this.reason,
    this.jobId,
    this.targetId,
    this.targetName,
    this.attempts = 0,
  });

  final String recordingId;

  /// Recording title (user content: shown, never logged); may be empty.
  final String title;
  final PendingReason reason;
  final String? jobId;
  final String? targetId;
  final String? targetName;
  final int attempts;

  @override
  bool operator ==(Object other) =>
      other is PendingExport &&
      other.recordingId == recordingId &&
      other.title == title &&
      other.reason == reason &&
      other.jobId == jobId &&
      other.targetId == targetId &&
      other.targetName == targetName &&
      other.attempts == attempts;

  @override
  int get hashCode => Object.hash(
    recordingId,
    title,
    reason,
    jobId,
    targetId,
    targetName,
    attempts,
  );

  @override
  String toString() => 'PendingExport($recordingId, ${reason.name})';
}

/// Builds the pending list from the outbox (`exports` rows that are not
/// `written`) and the jobs parked at the write step (pure; EXP-06).
///
/// A recording appears once per target that still misses the note, or
/// once with [PendingReason.noDestination] when its job waits for a
/// destination and no row exists. Rows of recordings whose latest job is
/// still before the write step (re-processing) are skipped.
List<PendingExport> buildPendingExports({
  required List<JobSnapshot> jobs,
  required List<ExportRow> exports,
  required List<VaultTargetRow> targets,
  required Map<String, String> titles,
}) {
  final latest = <String, JobSnapshot>{};
  for (final j in jobs) {
    final prev = latest[j.recordingId];
    if (prev == null || j.createdAt.isAfter(prev.createdAt)) {
      latest[j.recordingId] = j;
    }
  }
  final names = {for (final t in targets) t.id: t.displayName};
  final out = <PendingExport>[];
  final withRows = <String>{};

  for (final row in exports) {
    if (row.status == ExportStatus.written ||
        row.status == ExportStatus.skipped) {
      continue;
    }
    final job = latest[row.recordingId];
    if (job != null &&
        job.step != PipelineStepId.write &&
        job.state != JobState.done) {
      continue; // re-processing: the write step will run again anyway
    }
    withRows.add(row.recordingId);
    final reason = switch (job?.state) {
      JobState.waiting when job?.waitingReason == WaitingReason.destination =>
        PendingReason.accessRevoked,
      JobState.failed ||
      JobState.cancelled ||
      JobState.done ||
      null => PendingReason.failed,
      _ => PendingReason.retrying,
    };
    out.add(
      PendingExport(
        recordingId: row.recordingId,
        title: titles[row.recordingId] ?? '',
        reason: reason,
        jobId: job?.id,
        targetId: row.targetId,
        targetName: names[row.targetId],
        attempts: row.attempts,
      ),
    );
  }
  for (final job in latest.values) {
    if (job.state != JobState.waiting ||
        job.waitingReason != WaitingReason.destination ||
        withRows.contains(job.recordingId)) {
      continue;
    }
    out.add(
      PendingExport(
        recordingId: job.recordingId,
        title: titles[job.recordingId] ?? '',
        reason: targets.isEmpty
            ? PendingReason.noDestination
            : PendingReason.accessRevoked,
        jobId: job.id,
      ),
    );
  }
  out.sort((a, b) {
    final r = a.reason.index.compareTo(b.reason.index);
    return r != 0 ? r : a.recordingId.compareTo(b.recordingId);
  });
  return out;
}
