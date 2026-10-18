/// The canonical pipeline vocabulary (vv-pipeline-orchestrator → States).
///
/// Names are persisted in `jobs.step` / `jobs.status`; renaming a value is a
/// schema change.
library;

/// Processing steps in pipeline order. `diarize` and `classify` only run
/// when enabled (diarization per profile, classification when profile =
/// auto); `mindMap` (MAP-01) only when the mind-map mode is `auto` or the
/// user requested one.
enum PipelineStepId {
  transcribe,
  diarize,
  classify,
  extract,
  mindMap,
  render,
  write;

  /// The state a job is in while this step runs.
  JobState get activeState => switch (this) {
    transcribe => JobState.transcribing,
    diarize => JobState.diarizing,
    classify => JobState.classifying,
    extract => JobState.extracting,
    mindMap => JobState.mapping,
    render => JobState.rendering,
    write => JobState.writing,
  };

  /// The resting state a job waits in before this step starts.
  JobState get restingBefore => switch (this) {
    transcribe => JobState.queued,
    diarize || classify || extract => JobState.transcribed,
    mindMap || render => JobState.extracted,
    write => JobState.rendered,
  };

  /// The resting state reached when this step completes and another follows.
  JobState get restingAfter => switch (this) {
    transcribe || diarize || classify => JobState.transcribed,
    extract || mindMap => JobState.extracted,
    render => JobState.rendered,
    write => JobState.done,
  };
}

/// Every state a job can be in.
///
/// ```text
/// queued → transcribing → transcribed → diarizing? → classifying?
///        → extracting → extracted → mapping? → rendering → rendered
///        → writing → done
/// any → failed · any → cancelled · active → paused · any → waiting(reason)
/// ```
enum JobState {
  queued,
  transcribing,
  transcribed,
  diarizing,
  classifying,
  extracting,
  extracted,
  mapping,
  rendering,
  rendered,
  writing,
  done,
  failed,
  cancelled,
  paused,
  waiting;

  /// A step is running.
  bool get isActive => const {
    transcribing,
    diarizing,
    classifying,
    extracting,
    mapping,
    rendering,
    writing,
  }.contains(this);

  /// Between steps: the worker may pick the job up.
  bool get isResting =>
      const {queued, transcribed, extracted, rendered}.contains(this);

  /// No further automatic progress (`failed` can still be retried by the
  /// user, `cancelled` can be retried or re-run).
  bool get isTerminal => const {done, failed, cancelled}.contains(this);

  /// Resting states the worker queries for.
  static const Set<JobState> runnable = {
    queued,
    transcribed,
    extracted,
    rendered,
  };
}

/// Why a job is `waiting`. It resumes automatically when the reason clears.
enum WaitingReason { modelMissing, profileChoice, review, destination }

/// Failure classes (vv-pipeline-orchestrator → Retry policy).
enum FailureKind { retryable, permanent }

/// Immutable view of a persisted job.
class JobSnapshot {
  const JobSnapshot({
    required this.id,
    required this.recordingId,
    required this.state,
    required this.step,
    required this.createdAt,
    required this.updatedAt,
    this.progress = 0,
    this.attempts = 0,
    this.priority = 0,
    this.failureKind,
    this.errorDetail,
    this.waitingReason,
    this.notBefore,
    this.checkpoint = const {},
  });

  final String id;
  final String recordingId;
  final JobState state;

  /// The step running now (active states) or next to run.
  final PipelineStepId step;
  final double progress;

  /// Attempts of the current step (reset when a step completes).
  final int attempts;
  final int priority;
  final FailureKind? failureKind;

  /// Content-free failure type name (never messages or user content).
  final String? errorDetail;
  final WaitingReason? waitingReason;

  /// Earliest time of the next automatic retry.
  final DateTime? notBefore;

  /// Step checkpoint, e.g. `{nextChunk, modelId, paramsHash}`.
  final Map<String, Object?> checkpoint;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobSnapshot copyWith({
    JobState? state,
    PipelineStepId? step,
    double? progress,
    int? attempts,
    int? priority,
    FailureKind? Function()? failureKind,
    String? Function()? errorDetail,
    WaitingReason? Function()? waitingReason,
    DateTime? Function()? notBefore,
    Map<String, Object?>? checkpoint,
    DateTime? updatedAt,
  }) => JobSnapshot(
    id: id,
    recordingId: recordingId,
    state: state ?? this.state,
    step: step ?? this.step,
    progress: progress ?? this.progress,
    attempts: attempts ?? this.attempts,
    priority: priority ?? this.priority,
    failureKind: failureKind != null ? failureKind() : this.failureKind,
    errorDetail: errorDetail != null ? errorDetail() : this.errorDetail,
    waitingReason: waitingReason != null ? waitingReason() : this.waitingReason,
    notBefore: notBefore != null ? notBefore() : this.notBefore,
    checkpoint: checkpoint ?? this.checkpoint,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() => 'JobSnapshot($id, ${state.name}, ${step.name})';
}
