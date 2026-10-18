import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// Heavy models; at most one is loaded at a time (LLM-07 memory rule).
enum HeavyModel { stt, llm }

/// What a step hands back to the orchestrator.
sealed class StepResult {
  const StepResult();
}

/// The step finished. [commit] (optional) writes the step's final outputs;
/// the orchestrator runs it in the same transaction as the job's move to the
/// next step. It must throw on failure so the transaction rolls back.
final class StepSucceeded extends StepResult {
  const StepSucceeded({this.commit});

  final Future<void> Function()? commit;
}

/// The step failed; the orchestrator classifies [failure] (retry policy)
/// unless the step knows better and sets [kind] (e.g. invalid audio is
/// permanent even though it surfaces as a storage failure).
final class StepFailed extends StepResult {
  const StepFailed(this.failure, {this.kind});

  final Failure failure;
  final FailureKind? kind;
}

/// Thrown inside step code (checkpoint writes, commits) to abort the step
/// with [failure]; the orchestrator turns it into a [StepFailed].
class StepAbort implements Exception {
  const StepAbort(this.failure);

  final Failure failure;

  @override
  String toString() => 'StepAbort(${failure.runtimeType})';
}

/// The step cannot run until [reason] clears (not a failure).
final class StepWaiting extends StepResult {
  const StepWaiting(this.reason);

  final WaitingReason reason;
}

/// Services the orchestrator gives a running step.
abstract interface class StepContext {
  JobSnapshot get job;

  /// Cancelled when the user cancels/pauses the job or the worker stops.
  CancelToken get cancel;

  /// Progress of this step, 0.0–1.0 (emitted as a `JobEvent`).
  void reportProgress(double fraction);

  /// Persists a chunk checkpoint. [writes] (the chunk's outputs) and the
  /// checkpoint are committed in one transaction, so a kill never leaves
  /// outputs without their checkpoint or vice versa.
  Future<void> saveCheckpoint(
    Map<String, Object?> checkpoint, {
    double? progress,
    Future<void> Function()? writes,
  });
}

/// One processing step (vv-pipeline-orchestrator → States).
///
/// Steps must be idempotent: outputs are keyed by (job, step, chunk) and a
/// re-run overwrites instead of appending.
abstract interface class PipelineStep {
  PipelineStepId get id;

  /// The heavy model this step needs loaded, if any.
  HeavyModel? get model;

  /// Whether the step applies to this job (e.g. diarization per profile).
  bool canRun(JobSnapshot job);

  Future<StepResult> run(StepContext ctx);
}

/// A step whose applicability needs an async lookup (a setting, a request
/// flag). The orchestrator asks before the step starts, so a disabled step
/// is skipped without touching the model gate.
abstract interface class AsyncEnabledStep implements PipelineStep {
  Future<bool> isEnabled(JobSnapshot job);
}

/// How a failure is handled: retried with backoff, parked as waiting, or
/// failed permanently.
sealed class FailureDisposition {
  const FailureDisposition();
}

final class RetryDisposition extends FailureDisposition {
  const RetryDisposition();
}

final class PermanentDisposition extends FailureDisposition {
  const PermanentDisposition();
}

final class WaitDisposition extends FailureDisposition {
  const WaitDisposition(this.reason);

  final WaitingReason reason;
}

/// Retry policy classification: OOM, transient IO and destination problems
/// are retryable; a missing model waits; everything else (corrupt model,
/// invalid audio, native/unexpected errors) is permanent.
FailureDisposition classifyFailure(Failure failure) => switch (failure) {
  ModelMissingFailure() => const WaitDisposition(WaitingReason.modelMissing),
  PermissionFailure() => const WaitDisposition(WaitingReason.destination),
  OutOfMemoryFailure() ||
  StorageFailure() ||
  NetworkFailure() => const RetryDisposition(),
  // CancelledFailure, NativeFailure, EgressDeniedFailure, UnexpectedFailure
  // and failure types added later: no automatic retry.
  _ => const PermanentDisposition(),
};
