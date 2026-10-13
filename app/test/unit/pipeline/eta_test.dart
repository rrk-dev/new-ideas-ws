import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/pipeline/domain/eta.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/throughput.dart';

final t0 = DateTime.utc(2026, 10, 13, 9);

JobSnapshot job(
  JobState state,
  PipelineStepId step, {
  double progress = 0,
  DateTime? at,
  String id = 'j1',
}) => JobSnapshot(
  id: id,
  recordingId: 'r1',
  state: state,
  step: step,
  progress: progress,
  createdAt: t0,
  updatedAt: at ?? t0,
);

/// A device whose true per-step speed is [truth] (seconds per audio second).
/// Runs one job through the [ThroughputObserver] like the `jobs` stream
/// would (checkpoints every 10 %) and returns the learned stats.
ThroughputStats learn(
  Map<PipelineStepId, double> truth,
  Duration audio, {
  ThroughputStats stats = const ThroughputStats(),
  double jitter = 1,
}) {
  final observer = ThroughputObserver();
  var now = t0;
  var learned = stats;
  void feed(JobSnapshot s) {
    final m = observer.observe(s, audio);
    if (m != null) learned = learned.record(m.step, m.factor);
  }

  for (final step in kDefaultStepPlan) {
    final total = truth[step]! * jitter * audio.inSeconds;
    feed(job(step.restingBefore, step, at: now));
    for (var i = 0; i <= 10; i++) {
      feed(job(step.activeState, step, progress: i / 10, at: now));
      if (i < 10) now = now.add(Duration(milliseconds: (total * 100).round()));
    }
    final next = kDefaultStepPlan.indexOf(step) + 1;
    feed(
      next < kDefaultStepPlan.length
          ? job(
              kDefaultStepPlan[next].restingBefore,
              kDefaultStepPlan[next],
              at: now,
            )
          : job(JobState.done, step, progress: 1, at: now),
    );
  }
  return learned;
}

void main() {
  const truth = {
    PipelineStepId.transcribe: 0.4, // RTF 0.4
    PipelineStepId.extract: 0.25,
    PipelineStepId.render: 0.001,
    PipelineStepId.write: 0.002,
  };
  const audio = Duration(minutes: 30);

  group('ThroughputStats', () {
    test('running mean, then EMA capped at maxSamples', () {
      var s = const ThroughputStats();
      s = s.record(PipelineStepId.transcribe, 1);
      expect(s[PipelineStepId.transcribe]!.factor, 1);
      s = s.record(PipelineStepId.transcribe, 3);
      expect(s[PipelineStepId.transcribe]!.factor, 2);
      for (var i = 0; i < 20; i++) {
        s = s.record(PipelineStepId.transcribe, 0.5);
      }
      expect(s[PipelineStepId.transcribe]!.samples, ThroughputStats.maxSamples);
      expect(s[PipelineStepId.transcribe]!.factor, closeTo(0.5, 0.03));
    });

    test('drops outliers and survives JSON round-trip / garbage', () {
      final s = const ThroughputStats()
          .record(PipelineStepId.extract, 0.3)
          .record(PipelineStepId.extract, double.nan)
          .record(PipelineStepId.extract, 1e6);
      expect(s[PipelineStepId.extract]!.factor, 0.3);
      final back = ThroughputStats.fromJson(s.toJson());
      expect(back[PipelineStepId.extract]!.factor, 0.3);
      expect(back[PipelineStepId.extract]!.samples, 1);
      expect(ThroughputStats.fromJson('nope').steps, isEmpty);
      expect(
        ThroughputStats.fromJson({
          'extract': {'f': -1, 'n': 1},
          'bogus': {'f': 1, 'n': 1},
        }).steps,
        isEmpty,
      );
    });
  });

  group('ThroughputObserver', () {
    test('measures a full run as wall time per audio second', () {
      final stats = learn(truth, audio);
      for (final s in kDefaultStepPlan) {
        expect(stats[s]!.factor, closeTo(truth[s]!, truth[s]! * 0.01));
      }
    });

    test('drops paused/failed runs; normalises resumed runs', () {
      final o = ThroughputObserver();
      const a = Duration(seconds: 100);
      o.observe(job(JobState.transcribing, PipelineStepId.transcribe), a);
      expect(
        o.observe(
          job(
            JobState.paused,
            PipelineStepId.transcribe,
            at: t0.add(const Duration(seconds: 10)),
          ),
          a,
        ),
        isNull,
      );
      // First seen at 50 % (resumed after a kill), finishes 20 s later:
      // 20 s for 50 s of audio → 0.4.
      o.observe(
        job(
          JobState.transcribing,
          PipelineStepId.transcribe,
          progress: 0.5,
          at: t0,
        ),
        a,
      );
      final m = o.observe(
        job(
          JobState.transcribed,
          PipelineStepId.extract,
          at: t0.add(const Duration(seconds: 20)),
        ),
        a,
      );
      expect(m!.step, PipelineStepId.transcribe);
      expect(m.factor, closeTo(0.4, 1e-9));
    });

    test('a coalesced resting snapshot still ends the previous step', () {
      final o = ThroughputObserver();
      const a = Duration(seconds: 10);
      o.observe(job(JobState.rendering, PipelineStepId.render), a);
      final m = o.observe(
        job(
          JobState.writing,
          PipelineStepId.write,
          at: t0.add(const Duration(seconds: 1)),
        ),
        a,
      );
      expect(m!.step, PipelineStepId.render);
      expect(m.factor, closeTo(0.1, 1e-9));
    });
  });

  group('estimateRemaining', () {
    test('[APP-04/AC1] ETA from measured throughput is within ±30% of the '
        'real remaining time (host simulation; device run in '
        'docs/test-plans/device/APP-04.md)', () {
      // Learn on two earlier recordings, then process a third one on a
      // device that is 20 % slower today (thermal) — the ETA must stay within
      // ±30 % of the true remaining time at every checkpoint.
      var stats = learn(truth, const Duration(minutes: 10));
      stats = learn(truth, const Duration(minutes: 45), stats: stats);
      const slow = 1.2;
      final trueTotal = {
        for (final s in kDefaultStepPlan) s: truth[s]! * slow * audio.inSeconds,
      };
      for (final step in kDefaultStepPlan) {
        final idx = kDefaultStepPlan.indexOf(step);
        final later = kDefaultStepPlan
            .skip(idx + 1)
            .fold<double>(0, (sum, s) => sum + trueTotal[s]!);
        for (var i = 1; i < 10; i++) {
          final p = i / 10;
          final elapsed = trueTotal[step]! * p;
          final eta = estimateRemaining(
            job: job(step.activeState, step, progress: p),
            audio: audio,
            stats: stats,
            now: t0.add(Duration(milliseconds: (elapsed * 1000).round())),
            stepStartedAt: t0,
          )!;
          final real = trueTotal[step]! * (1 - p) + later;
          final err = (eta.inMilliseconds / 1000 - real).abs() / real;
          expect(
            err,
            lessThanOrEqualTo(0.30),
            reason: '${step.name} at $p: eta $eta vs real ${real}s',
          );
        }
      }
      // Queued (nothing started): the whole job.
      final queued = estimateRemaining(
        job: job(JobState.queued, PipelineStepId.transcribe),
        audio: audio,
        stats: stats,
        now: t0,
      )!;
      final real = trueTotal.values.fold<double>(0, (a, b) => a + b);
      expect((queued.inSeconds - real).abs() / real, lessThanOrEqualTo(0.30));
    });

    test('[APP-04/AC1] mis-calibrated stats converge via live progress', () {
      // Stats say RTF 0.2 but this run really goes at 0.6.
      final stats = const ThroughputStats()
          .record(PipelineStepId.transcribe, 0.2)
          .record(PipelineStepId.extract, 0.25)
          .record(PipelineStepId.render, 0.001)
          .record(PipelineStepId.write, 0.001);
      const a = Duration(minutes: 10);
      const p = 0.8;
      final eta = estimateRemaining(
        job: job(JobState.transcribing, PipelineStepId.transcribe, progress: p),
        audio: a,
        stats: stats,
        now: t0.add(Duration(milliseconds: (0.6 * 600 * p * 1000).round())),
        stepStartedAt: t0,
      )!;
      final real = 0.6 * 600 * (1 - p) + (0.25 + 0.002) * 600;
      expect((eta.inSeconds - real).abs() / real, lessThanOrEqualTo(0.30));
    });

    test('no measurement and no live progress → estimating (null)', () {
      expect(
        estimateRemaining(
          job: job(JobState.transcribing, PipelineStepId.transcribe),
          audio: audio,
          stats: const ThroughputStats(),
          now: t0,
          stepStartedAt: t0,
        ),
        isNull,
      );
      // Live progress alone covers the step, but later steps are unknown.
      expect(
        estimateRemaining(
          job: job(
            JobState.transcribing,
            PipelineStepId.transcribe,
            progress: 0.5,
          ),
          audio: audio,
          stats: const ThroughputStats(),
          now: t0.add(const Duration(minutes: 1)),
          stepStartedAt: t0,
        ),
        isNull,
      );
      // ... but the last step can be estimated from live progress alone.
      expect(
        estimateRemaining(
          job: job(JobState.writing, PipelineStepId.write, progress: 0.5),
          audio: audio,
          stats: const ThroughputStats(),
          now: t0.add(const Duration(seconds: 2)),
          stepStartedAt: t0,
        ),
        const Duration(seconds: 2),
      );
    });

    test('step without checkpoints counts down from the expectation', () {
      final stats = learn(truth, audio);
      final at = t0.add(const Duration(minutes: 2));
      final eta = estimateRemaining(
        job: job(JobState.extracting, PipelineStepId.extract),
        audio: audio,
        stats: stats,
        now: at,
        stepStartedAt: t0,
      )!;
      final expected = (0.25 * 1800 - 120) + (0.003 * 1800);
      expect(eta.inSeconds, closeTo(expected, 2));
    });

    test('terminal and waiting jobs have no ETA', () {
      final stats = learn(truth, audio);
      for (final s in [JobState.done, JobState.failed, JobState.waiting]) {
        expect(
          estimateRemaining(
            job: job(s, PipelineStepId.extract),
            audio: audio,
            stats: stats,
            now: t0,
          ),
          isNull,
        );
      }
    });
  });

  group('buildProgressViews', () {
    test('queue positions and overall progress', () {
      final views = buildProgressViews(
        jobs: [
          job(JobState.transcribing, PipelineStepId.transcribe, progress: 0.5),
          job(JobState.queued, PipelineStepId.transcribe, id: 'j2'),
          job(JobState.queued, PipelineStepId.transcribe, id: 'j3'),
          job(JobState.done, PipelineStepId.write, id: 'j4'),
        ],
        recordings: const {
          'r1': RecordingFacts(title: 'Standup', duration: audio),
        },
        stats: const ThroughputStats(),
        now: t0,
        stepStart: (_) => (null, 0),
      );
      expect([for (final v in views) v.queuePosition], [null, 2, 3, null]);
      expect(views.first.recordingTitle, 'Standup');
      expect(views.first.overallProgress(), closeTo(0.125, 1e-9));
      expect(views.last.overallProgress(), 1);
    });
  });
}
