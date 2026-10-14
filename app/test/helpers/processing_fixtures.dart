import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

final _t0 = DateTime.utc(2026, 10, 13, 9);

/// A [JobProgressView] for widget/golden tests.
JobProgressView progressView({
  required String id,
  JobState state = JobState.transcribing,
  PipelineStepId step = PipelineStepId.transcribe,
  double progress = 0.4,
  String title = 'Weekly planning',
  Duration? eta,
  int? queuePosition,
  FailureKind? failureKind,
  WaitingReason? waitingReason,
  int createdMinute = 0,
}) => JobProgressView(
  job: JobSnapshot(
    id: id,
    recordingId: 'rec-$id',
    state: state,
    step: step,
    progress: progress,
    failureKind: failureKind,
    waitingReason: waitingReason,
    createdAt: _t0.add(Duration(minutes: createdMinute)),
    updatedAt: _t0,
  ),
  recordingTitle: title,
  eta: eta,
  queuePosition: queuePosition,
);

/// A realistic queue: one running, one queued, one waiting, one failed.
List<JobProgressView> sampleQueue() => [
  progressView(id: 'a', eta: const Duration(minutes: 4, seconds: 20)),
  progressView(
    id: 'b',
    state: JobState.queued,
    progress: 0,
    title: 'Call notes: warranty claim',
    eta: const Duration(minutes: 12),
    queuePosition: 2,
    createdMinute: 1,
  ),
  progressView(
    id: 'c',
    state: JobState.waiting,
    step: PipelineStepId.extract,
    progress: 0,
    title: '',
    waitingReason: WaitingReason.modelMissing,
    createdMinute: 2,
  ),
  progressView(
    id: 'd',
    state: JobState.failed,
    step: PipelineStepId.write,
    progress: 0,
    title: 'Design review',
    failureKind: FailureKind.retryable,
    createdMinute: 3,
  ),
];
