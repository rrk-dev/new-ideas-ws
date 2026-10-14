import 'package:vaultvoice/features/pipeline/domain/eta.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/throughput.dart';

/// Everything the status UI shows for one job (APP-04).
class JobProgressView {
  const JobProgressView({
    required this.job,
    required this.recordingTitle,
    this.eta,
    this.queuePosition,
  });

  final JobSnapshot job;

  /// User content: displayed in-app only, never logged.
  final String recordingTitle;

  /// Remaining time, `null` while estimating or when not applicable.
  final Duration? eta;

  /// 1-based place in the queue for jobs that wait their turn (`null` for
  /// the running job and for jobs that are not queued).
  final int? queuePosition;

  /// Fraction of the whole job, 0–1 (finished steps + current step).
  double overallProgress([List<PipelineStepId> plan = kDefaultStepPlan]) {
    if (job.state == JobState.done) return 1;
    final at = plan.indexOf(job.step);
    if (at < 0) return job.progress.clamp(0.0, 1.0);
    final inStep = job.state.isActive || job.state == JobState.paused
        ? job.progress.clamp(0.0, 1.0)
        : 0.0;
    return (at + inStep) / plan.length;
  }
}

/// Recording facts the views need.
class RecordingFacts {
  const RecordingFacts({required this.title, required this.duration});

  final String title;
  final Duration duration;
}

/// Jobs still in the pipeline (the global queue indicator counts these).
bool isInPipeline(JobSnapshot job) => !job.state.isTerminal;

/// Builds views for [jobs] (already in queue order) — see [estimateRemaining].
List<JobProgressView> buildProgressViews({
  required List<JobSnapshot> jobs,
  required Map<String, RecordingFacts> recordings,
  required ThroughputStats stats,
  required DateTime now,
  required (DateTime?, double) Function(String jobId) stepStart,
}) {
  final waitingTurn = [
    for (final j in jobs)
      if (j.state.isResting) j.id,
  ];
  final running = jobs.where((j) => j.state.isActive).length;
  return [
    for (final job in jobs)
      () {
        final facts = recordings[job.recordingId];
        final (startedAt, startProgress) = stepStart(job.id);
        final index = waitingTurn.indexOf(job.id);
        return JobProgressView(
          job: job,
          recordingTitle: facts?.title ?? '',
          eta: estimateRemaining(
            job: job,
            audio: facts?.duration ?? Duration.zero,
            stats: stats,
            now: now,
            stepStartedAt: startedAt,
            stepStartProgress: startProgress,
          ),
          queuePosition: index < 0 ? null : running + index + 1,
        );
      }(),
  ];
}
