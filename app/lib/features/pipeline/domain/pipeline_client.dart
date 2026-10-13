import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// A change of a job, for progress UI (APP-04) and notifications.
/// Content-free: ids, state and numbers only.
class JobEvent {
  const JobEvent({
    required this.jobId,
    required this.recordingId,
    required this.state,
    required this.step,
    required this.progress,
    this.failureKind,
    this.waitingReason,
  });

  factory JobEvent.of(JobSnapshot job) => JobEvent(
    jobId: job.id,
    recordingId: job.recordingId,
    state: job.state,
    step: job.step,
    progress: job.progress,
    failureKind: job.failureKind,
    waitingReason: job.waitingReason,
  );

  final String jobId;
  final String recordingId;
  final JobState state;
  final PipelineStepId step;
  final double progress;
  final FailureKind? failureKind;
  final WaitingReason? waitingReason;

  @override
  String toString() =>
      'JobEvent($jobId, ${state.name}, ${step.name}, '
      '${(progress * 100).round()}%)';
}

/// Commands to the pipeline worker. Implemented in-process by
/// `PipelineOrchestrator` and across isolates by `PipelineIsolateClient`.
abstract interface class PipelineClient {
  /// Progress and state changes of every job.
  Stream<JobEvent> get events;

  /// Queues processing of a recording; returns the job id.
  /// [userInitiated] ("Process now") jumps the queue.
  Future<Result<String>> enqueue(
    String recordingId, {
    bool userInitiated = false,
    String? profileId,
  });

  /// Moves a queued job to the front.
  Future<Result<void>> processNow(String jobId);

  Future<Result<void>> cancel(String jobId);

  /// Manual retry of a failed or cancelled job.
  Future<Result<void>> retry(String jobId);

  /// Re-runs from [from] (e.g. re-extract with another profile) keeping the
  /// transcript; downstream outputs are cleared.
  Future<Result<void>> rerun(
    String jobId,
    PipelineStepId from, {
    String? profileId,
  });

  /// Pauses a job (background/thermal) and stops its running step.
  Future<Result<void>> pause(String jobId);

  Future<Result<void>> resume(String jobId);

  /// The reason a job was waiting for has cleared (model installed, profile
  /// picked, result approved, vault access re-granted).
  Future<Result<void>> resolveWaiting(String jobId);

  /// Stops the worker. Running steps are interrupted without changing their
  /// persisted state; the next start recovers them.
  Future<void> dispose();
}
