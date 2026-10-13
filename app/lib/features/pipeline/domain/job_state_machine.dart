import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// A transition that the state machine does not allow (a bug in the caller,
/// not an expected failure).
class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.from, this.transition);

  final JobState from;
  final String transition;

  @override
  String toString() =>
      'InvalidTransitionException($transition from ${from.name})';
}

/// Automatic retry policy: exponential backoff 30 s → 2 min → 10 min, then
/// `failed(retryable)` with a user action.
class RetryPolicy {
  const RetryPolicy({
    this.backoff = const [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ],
  });

  /// Delay before automatic retry n (index 0 = first retry). Its length is
  /// the number of automatic retries.
  final List<Duration> backoff;

  /// Delay before the next automatic retry after attempt [attempts] failed,
  /// or null when no automatic retry is left.
  Duration? delayAfter(int attempts) {
    final index = attempts - 1;
    return index >= 0 && index < backoff.length ? backoff[index] : null;
  }
}

/// Pure transition rules for [JobSnapshot]s. Every method returns the next
/// snapshot or throws [InvalidTransitionException]; persisting it is the
/// orchestrator's job ("persist before act").
class JobStateMachine {
  const JobStateMachine({this.retry = const RetryPolicy()});

  final RetryPolicy retry;

  /// resting → `<step>ing`. Counts an attempt.
  JobSnapshot start(JobSnapshot job, DateTime now) {
    _require(job, 'start', job.state.isResting);
    return job.copyWith(
      state: job.step.activeState,
      attempts: job.attempts + 1,
      progress: 0,
      notBefore: () => null,
      waitingReason: () => null,
      updatedAt: now,
    );
  }

  /// Progress inside the active step (0.0–1.0), optionally with a new
  /// checkpoint.
  JobSnapshot progress(
    JobSnapshot job,
    double fraction,
    DateTime now, {
    Map<String, Object?>? checkpoint,
  }) {
    _require(job, 'progress', job.state.isActive);
    return job.copyWith(
      progress: fraction.clamp(0, 1).toDouble(),
      checkpoint: checkpoint,
      updatedAt: now,
    );
  }

  /// `<step>ing` → resting after the step, pointing at [next]; or `done`
  /// when [next] is null. Clears the step's checkpoint and errors.
  JobSnapshot complete(JobSnapshot job, PipelineStepId? next, DateTime now) {
    _require(job, 'complete', job.state.isActive);
    if (next != null && next.index <= job.step.index) {
      throw InvalidTransitionException(job.state, 'complete→${next.name}');
    }
    return job.copyWith(
      state: next == null ? JobState.done : job.step.restingAfter,
      step: next,
      progress: next == null ? 1 : 0,
      attempts: 0,
      checkpoint: const {},
      failureKind: () => null,
      errorDetail: () => null,
      updatedAt: now,
    );
  }

  /// Skips a disabled step while resting (e.g. no diarization): points the
  /// job at [next] without running anything.
  JobSnapshot skip(JobSnapshot job, PipelineStepId? next, DateTime now) {
    _require(job, 'skip', job.state.isResting);
    if (next == null) {
      return job.copyWith(state: JobState.done, progress: 1, updatedAt: now);
    }
    if (next.index <= job.step.index) {
      throw InvalidTransitionException(job.state, 'skip→${next.name}');
    }
    return job.copyWith(
      state: next.restingBefore,
      step: next,
      checkpoint: const {},
      updatedAt: now,
    );
  }

  /// `<step>ing` → resting with backoff (retryable, retries left) or
  /// `failed`. The checkpoint is kept so a retry resumes.
  JobSnapshot fail(
    JobSnapshot job,
    FailureKind kind,
    String detail,
    DateTime now,
  ) {
    _require(job, 'fail', job.state.isActive);
    final delay = kind == FailureKind.retryable
        ? retry.delayAfter(job.attempts)
        : null;
    return job.copyWith(
      state: delay == null ? JobState.failed : job.step.restingBefore,
      failureKind: () => kind,
      errorDetail: () => detail,
      notBefore: () => delay == null ? null : now.add(delay),
      updatedAt: now,
    );
  }

  /// active or resting → `waiting(reason)`.
  JobSnapshot wait(JobSnapshot job, WaitingReason reason, DateTime now) {
    _require(job, 'wait', job.state.isActive || job.state.isResting);
    return job.copyWith(
      state: JobState.waiting,
      waitingReason: () => reason,
      updatedAt: now,
    );
  }

  /// `waiting` → resting before the step; the reason cleared.
  JobSnapshot resolveWaiting(JobSnapshot job, DateTime now) {
    _require(job, 'resolveWaiting', job.state == JobState.waiting);
    return job.copyWith(
      state: job.step.restingBefore,
      waitingReason: () => null,
      attempts: 0,
      updatedAt: now,
    );
  }

  /// active → `paused` (backgrounded, thermal, low power).
  JobSnapshot pause(JobSnapshot job, DateTime now) {
    _require(job, 'pause', job.state.isActive || job.state.isResting);
    return job.copyWith(state: JobState.paused, updatedAt: now);
  }

  /// `paused` → resting before the step.
  JobSnapshot resume(JobSnapshot job, DateTime now) {
    _require(job, 'resume', job.state == JobState.paused);
    return job.copyWith(state: job.step.restingBefore, updatedAt: now);
  }

  /// any non-terminal (and `failed`) → `cancelled`.
  JobSnapshot cancel(JobSnapshot job, DateTime now) {
    _require(
      job,
      'cancel',
      job.state != JobState.done && job.state != JobState.cancelled,
    );
    return job.copyWith(
      state: JobState.cancelled,
      notBefore: () => null,
      updatedAt: now,
    );
  }

  /// `failed` / `cancelled` → resting before the step (manual retry).
  JobSnapshot retryNow(JobSnapshot job, DateTime now) {
    _require(
      job,
      'retry',
      job.state == JobState.failed || job.state == JobState.cancelled,
    );
    return job.copyWith(
      state: job.step.restingBefore,
      attempts: 0,
      failureKind: () => null,
      errorDetail: () => null,
      notBefore: () => null,
      updatedAt: now,
    );
  }

  /// Requeue from [from] (re-extract, re-render, …). Not while a step runs.
  JobSnapshot rerun(JobSnapshot job, PipelineStepId from, DateTime now) {
    _require(job, 'rerun', !job.state.isActive);
    return job.copyWith(
      state: from.restingBefore,
      step: from,
      progress: 0,
      attempts: 0,
      checkpoint: const {},
      failureKind: () => null,
      errorDetail: () => null,
      waitingReason: () => null,
      notBefore: () => null,
      updatedAt: now,
    );
  }

  /// Startup recovery after a kill: active → resting before the same step,
  /// keeping checkpoint and attempts so the step resumes.
  JobSnapshot recover(JobSnapshot job, DateTime now) {
    _require(job, 'recover', job.state.isActive);
    return job.copyWith(state: job.step.restingBefore, updatedAt: now);
  }

  static void _require(JobSnapshot job, String transition, bool ok) {
    if (!ok) throw InvalidTransitionException(job.state, transition);
  }
}
