import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// Rolling throughput of one pipeline step on this device (APP-04).
///
/// [factor] = wall-clock seconds the step needs per second of recorded
/// audio. For `transcribe` this is exactly whisper's real-time factor (RTF);
/// for `extract` it is the LLM time normalised by audio length, a proxy for
/// tokens/s (transcript tokens scale linearly with speech length), which is
/// all the UI isolate can observe from the `jobs` table.
class StepThroughput {
  const StepThroughput({required this.factor, required this.samples});

  final double factor;

  /// Number of measured runs folded into [factor] (capped at
  /// [ThroughputStats.maxSamples]).
  final int samples;

  Map<String, Object?> toJson() => {'f': factor, 'n': samples};

  static StepThroughput? fromJson(Object? json) {
    if (json is! Map) return null;
    final f = json['f'];
    final n = json['n'];
    if (f is! num || n is! num || !f.isFinite || f <= 0 || n < 1) return null;
    return StepThroughput(factor: f.toDouble(), samples: n.toInt());
  }
}

/// Measured per-step throughput, persisted in the `settings` table under
/// [settingsKey] (vv-pipeline-orchestrator → Progress & ETA).
class ThroughputStats {
  const ThroughputStats([this.steps = const {}]);

  /// Tolerant decoding: unknown steps and malformed entries are dropped.
  factory ThroughputStats.fromJson(Object? json) {
    if (json is! Map) return const ThroughputStats();
    final steps = <PipelineStepId, StepThroughput>{};
    for (final id in PipelineStepId.values) {
      final t = StepThroughput.fromJson(json[id.name]);
      if (t != null) steps[id] = t;
    }
    return ThroughputStats(steps);
  }

  /// `settings` key; bump the suffix if the JSON shape changes.
  static const settingsKey = 'pipeline.throughput.v1';

  /// Running mean over the first runs, then an exponential moving average
  /// with weight `1 / maxSamples` so the estimate follows thermal/OS changes.
  static const maxSamples = 5;

  /// Measurements outside this range are discarded as outliers (e.g. a step
  /// that stalled for hours in the background, or a near-zero clip).
  static const minFactor = 0.0005;
  static const maxFactor = 100.0;

  final Map<PipelineStepId, StepThroughput> steps;

  StepThroughput? operator [](PipelineStepId step) => steps[step];

  /// Folds one measured run of [step] into the stats.
  ThroughputStats record(PipelineStepId step, double factor) {
    if (!factor.isFinite || factor < minFactor || factor > maxFactor) {
      return this;
    }
    final old = steps[step];
    final n = old == null ? 1 : (old.samples + 1).clamp(1, maxSamples);
    final mean = old == null ? factor : old.factor + (factor - old.factor) / n;
    return ThroughputStats({
      ...steps,
      step: StepThroughput(factor: mean, samples: n),
    });
  }

  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in steps.entries)
      key.name: value.toJson(),
  };
}
