import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// `jobs.kind` of recording-processing jobs.
const processJobKind = 'process';

T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

T? _maybeByName<T extends Enum>(List<T> values, String? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Row → domain. Unknown persisted names (written by a newer app version)
/// map to `failed` so the job is surfaced instead of run blindly.
JobSnapshot jobFromRow(JobRow row) {
  final state = _maybeByName(JobState.values, row.status);
  return JobSnapshot(
    id: row.id,
    recordingId: row.recordingId,
    state: state ?? JobState.failed,
    step: _byName(PipelineStepId.values, row.step, PipelineStepId.transcribe),
    progress: row.progress,
    attempts: row.attempts,
    priority: row.priority,
    failureKind: state == null
        ? FailureKind.permanent
        : _maybeByName(FailureKind.values, row.errorCode),
    errorDetail: state == null ? 'unknown state' : row.errorDetail,
    waitingReason: _maybeByName(WaitingReason.values, row.waitingReason),
    notBefore: row.notBefore,
    checkpoint: row.checkpoint,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

/// Domain → full row (every mutable column written).
JobsCompanion jobToCompanion(JobSnapshot job) => JobsCompanion(
  id: Value(job.id),
  recordingId: Value(job.recordingId),
  kind: const Value(processJobKind),
  step: Value(job.step.name),
  status: Value(job.state.name),
  progress: Value(job.progress),
  attempts: Value(job.attempts),
  priority: Value(job.priority),
  errorCode: Value(job.failureKind?.name),
  errorDetail: Value(job.errorDetail),
  waitingReason: Value(job.waitingReason?.name),
  notBefore: Value(job.notBefore),
  createdAt: Value(job.createdAt),
  updatedAt: Value(job.updatedAt),
  checkpoint: Value(job.checkpoint),
);
