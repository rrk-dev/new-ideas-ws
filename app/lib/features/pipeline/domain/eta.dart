import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/throughput.dart';

/// Steps the standard pipeline runs, in order (`defaultSteps` in FND-05;
/// diarize/classify join when STT-05/PRF-06 register them).
const List<PipelineStepId> kDefaultStepPlan = [
  PipelineStepId.transcribe,
  PipelineStepId.extract,
  PipelineStepId.render,
  PipelineStepId.write,
];

/// Below this progress the in-step extrapolation is too noisy to use alone.
const double kMinExtrapolationProgress = 0.05;

/// Remaining-time estimate for one job (APP-04).
///
/// Per step `s` still to run: `factor(s) × audio` (measured on this device,
/// [ThroughputStats]). For the running step the measured expectation is
/// blended with the live extrapolation `elapsed × (1 − p) / p`, weighted by
/// progress `p`, so the estimate converges on the real speed of this run.
/// Returns `null` ("estimating…") when any remaining step has neither a
/// measurement nor enough live progress — never a made-up number.
Duration? estimateRemaining({
  required JobSnapshot job,
  required Duration audio,
  required ThroughputStats stats,
  required DateTime now,
  DateTime? stepStartedAt,
  double stepStartProgress = 0,
  List<PipelineStepId> plan = kDefaultStepPlan,
}) {
  if (job.state.isTerminal || job.state == JobState.waiting) return null;
  final audioSec = audio.inMicroseconds / Duration.microsecondsPerSecond;
  double? expected(PipelineStepId s) {
    final t = stats[s];
    return t == null || audioSec <= 0 ? null : t.factor * audioSec;
  }

  var total = 0.0;
  // The current step.
  final p = job.progress.clamp(0.0, 1.0);
  final measured = expected(job.step);
  if (job.state.isActive) {
    double? live;
    final ranFor = p - stepStartProgress;
    if (stepStartedAt != null && ranFor >= kMinExtrapolationProgress) {
      final elapsed =
          now.difference(stepStartedAt).inMicroseconds /
          Duration.microsecondsPerSecond;
      live = elapsed * (1 - p) / ranFor;
    }
    final double? fromMeasured;
    if (measured == null) {
      fromMeasured = null;
    } else if (p > 0 || stepStartedAt == null) {
      fromMeasured = measured * (1 - p);
    } else {
      // No checkpoint yet (e.g. extraction reports progress only live):
      // count down from the expectation.
      final elapsed =
          now.difference(stepStartedAt).inMicroseconds /
          Duration.microsecondsPerSecond;
      fromMeasured = (measured - elapsed).clamp(0.0, measured);
    }
    final double current;
    if (live != null && fromMeasured != null) {
      current = p * live + (1 - p) * fromMeasured;
    } else if (live != null) {
      current = live;
    } else if (fromMeasured != null) {
      current = fromMeasured;
    } else {
      return null;
    }
    total += current;
  } else {
    if (measured == null) return null;
    total += measured * (job.state.isResting ? 1 : 1 - p);
  }
  // Later steps.
  final at = plan.indexOf(job.step);
  if (at < 0) return null;
  for (final s in plan.skip(at + 1)) {
    final e = expected(s);
    if (e == null) return null;
    total += e;
  }
  return Duration(
    microseconds: (total * Duration.microsecondsPerSecond).round(),
  );
}

/// A finished step run measured from consecutive job snapshots.
class StepMeasurement {
  const StepMeasurement(this.step, this.factor);

  final PipelineStepId step;
  final double factor;

  @override
  String toString() => 'StepMeasurement(${step.name}, $factor)';
}

/// Watches `jobs` snapshots and turns each uninterrupted step run into a
/// [StepMeasurement]: started when the job entered the step's active state
/// (persisted before act, FND-05), finished when the job moved on to a later
/// step / `done`. Paused, cancelled, failed or app-killed runs are dropped;
/// a resume from a checkpoint is normalised by the remaining fraction.
class ThroughputObserver {
  final Map<String, _RunStart> _runs = {};

  /// When [jobId]'s current step started (for the live ETA), if seen.
  DateTime? stepStartedAt(String jobId) => _runs[jobId]?.at;

  /// Progress of [jobId] when its current step was first seen running.
  double stepStartProgress(String jobId) => _runs[jobId]?.progress ?? 0;

  /// Feeds the latest snapshot of one job. [audio] is the recording length.
  StepMeasurement? observe(JobSnapshot job, Duration audio) {
    final run = _runs[job.id];
    if (job.state.isActive) {
      if (run != null && run.step == job.step) return null;
      _runs[job.id] = _RunStart(job.step, job.updatedAt, job.progress);
      // The resting snapshot between two steps may have been coalesced by
      // the stream: the previous step ended when this one started.
      return run != null && job.step.index > run.step.index
          ? _measure(run, job.updatedAt, audio)
          : null;
    }
    _runs.remove(job.id);
    if (run == null) return null;
    final finished =
        job.state == JobState.done ||
        (job.state.isResting && job.step.index > run.step.index);
    if (!finished) return null; // paused / failed / cancelled / waiting
    return _measure(run, job.updatedAt, audio);
  }

  static StepMeasurement? _measure(
    _RunStart run,
    DateTime endedAt,
    Duration audio,
  ) {
    final remaining = 1 - run.progress;
    final audioSec = audio.inMicroseconds / Duration.microsecondsPerSecond;
    if (audioSec <= 0 || remaining <= 0) return null;
    final wall =
        endedAt.difference(run.at).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (wall <= 0) return null;
    return StepMeasurement(run.step, wall / (audioSec * remaining));
  }

  /// Drops state for jobs that no longer exist.
  void retain(Set<String> jobIds) =>
      _runs.removeWhere((id, _) => !jobIds.contains(id));
}

class _RunStart {
  const _RunStart(this.step, this.at, this.progress);

  final PipelineStepId step;
  final DateTime at;
  final double progress;
}
