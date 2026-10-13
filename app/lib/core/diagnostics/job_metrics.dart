import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/clock.dart';

/// Performance numbers for one processing step of one job (FND-07; input to
/// QA-03). Content-free: IDs, durations and counts only. Stored on device and
/// leaves it only inside a user-initiated diagnostics export.
@immutable
final class JobMetrics {
  const JobMetrics({
    required this.jobId,
    required this.step,
    required this.startedAt,
    required this.wallTime,
    this.audioDuration,
    this.promptTokens,
    this.prefillTime,
    this.generatedTokens,
    this.decodeTime,
    this.peakRssBytes,
    this.batteryStartPercent,
    this.batteryEndPercent,
    this.thermalStates = const [],
  });

  factory JobMetrics.fromJson(Map<String, Object?> json) {
    Duration? ms(Object? v) =>
        v is num ? Duration(microseconds: (v * 1000).round()) : null;
    int? integer(Object? v) => v is num ? v.toInt() : null;
    return JobMetrics(
      jobId: '${json['job']}',
      step: '${json['step']}',
      startedAt: DateTime.parse('${json['started']}'),
      wallTime: ms(json['wall_ms']) ?? Duration.zero,
      audioDuration: ms(json['audio_ms']),
      promptTokens: integer(json['prompt_tokens']),
      prefillTime: ms(json['prefill_ms']),
      generatedTokens: integer(json['gen_tokens']),
      decodeTime: ms(json['decode_ms']),
      peakRssBytes: integer(json['peak_rss_bytes']),
      batteryStartPercent: integer(json['battery_start_pct']),
      batteryEndPercent: integer(json['battery_end_pct']),
      thermalStates: [
        for (final s in (json['thermal'] as List<Object?>?) ?? const []) '$s',
      ],
    );
  }

  /// Job identifier (never a file name; sanitized with [LogId]).
  final String jobId;

  /// Pipeline step, e.g. `transcribe`, `extract`.
  final String step;
  final DateTime startedAt;
  final Duration wallTime;

  /// Length of the processed audio (STT steps).
  final Duration? audioDuration;
  final int? promptTokens;
  final Duration? prefillTime;
  final int? generatedTokens;
  final Duration? decodeTime;

  /// Peak resident set size of the process observed at the end of the step.
  final int? peakRssBytes;
  final int? batteryStartPercent;
  final int? batteryEndPercent;

  /// Thermal states seen during the step, in order (`nominal`, `serious` …).
  final List<String> thermalStates;

  /// Real-time factor: processing time / audio duration (lower is faster).
  double? get realTimeFactor =>
      audioDuration == null || audioDuration!.inMicroseconds == 0
      ? null
      : wallTime.inMicroseconds / audioDuration!.inMicroseconds;

  double? get prefillTokensPerSecond => _rate(promptTokens, prefillTime);

  double? get decodeTokensPerSecond => _rate(generatedTokens, decodeTime);

  /// Battery percentage points used (positive = drained).
  int? get batteryDeltaPercent =>
      batteryStartPercent == null || batteryEndPercent == null
      ? null
      : batteryStartPercent! - batteryEndPercent!;

  static double? _rate(int? tokens, Duration? time) =>
      tokens == null || time == null || time.inMicroseconds == 0
      ? null
      : tokens / (time.inMicroseconds / Duration.microsecondsPerSecond);

  Map<String, Object?> toJson() {
    double? ms(Duration? d) => d == null ? null : d.inMicroseconds / 1000;
    final json = <String, Object?>{
      'job': LogId(jobId).value,
      'step': LogId(step).value,
      'started': startedAt.toUtc().toIso8601String(),
      'wall_ms': ms(wallTime),
      'audio_ms': ms(audioDuration),
      'rtf': realTimeFactor,
      'prompt_tokens': promptTokens,
      'prefill_ms': ms(prefillTime),
      'prefill_tok_s': prefillTokensPerSecond,
      'gen_tokens': generatedTokens,
      'decode_ms': ms(decodeTime),
      'decode_tok_s': decodeTokensPerSecond,
      'peak_rss_bytes': peakRssBytes,
      'battery_start_pct': batteryStartPercent,
      'battery_end_pct': batteryEndPercent,
      'battery_delta_pct': batteryDeltaPercent,
      'thermal': [for (final s in thermalStates) LogId(s).value],
    }..removeWhere((_, v) => v == null);
    return json;
  }
}

/// Current battery level; `null` when the platform cannot tell.
abstract interface class BatteryProbe {
  Future<int?> levelPercent();
}

/// Used until a platform battery probe is wired in (follow-up FND-09).
class UnavailableBatteryProbe implements BatteryProbe {
  const UnavailableBatteryProbe();

  @override
  Future<int?> levelPercent() async => null;
}

/// Peak memory of this process.
abstract interface class MemoryProbe {
  int? peakRssBytes();
}

/// `ProcessInfo.maxRss`: process-lifetime high-water mark (Android VmHWM /
/// iOS `ru_maxrss`). Native allocations by whisper/llama are included because
/// they live in the same process.
class ProcessMemoryProbe implements MemoryProbe {
  const ProcessMemoryProbe();

  @override
  int? peakRssBytes() {
    try {
      return ProcessInfo.maxRss;
    } on Object {
      return null;
    }
  }
}

/// Local, bounded store of [JobMetrics].
abstract interface class MetricsStore {
  Future<void> add(JobMetrics metrics);

  Future<List<JobMetrics>> all();
}

/// Keeps metrics in memory (tests, and before storage is available).
class InMemoryMetricsStore implements MetricsStore {
  final _items = <JobMetrics>[];

  @override
  Future<void> add(JobMetrics metrics) async => _items.add(metrics);

  @override
  Future<List<JobMetrics>> all() async => List.unmodifiable(_items);
}

/// JSON-lines file in app-private storage, trimmed to the newest
/// [maxRecords]. (Moves to a drift table once FND-04 lands: FND-09.)
class JsonlMetricsStore implements MetricsStore {
  JsonlMetricsStore(this.file, {this.maxRecords = 500});

  final File file;
  final int maxRecords;

  @override
  Future<void> add(JobMetrics metrics) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(metrics.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
    final lines = await _lines();
    if (lines.length > maxRecords) {
      final kept = lines.sublist(lines.length - maxRecords);
      await file.writeAsString('${kept.join('\n')}\n', flush: true);
    }
  }

  @override
  Future<List<JobMetrics>> all() async => [
    for (final line in await _lines()) ?_parse(line),
  ];

  Future<List<String>> _lines() async => file.existsSync()
      ? (await file.readAsLines()).where((l) => l.trim().isNotEmpty).toList()
      : <String>[];

  static JobMetrics? _parse(String line) {
    try {
      final json = jsonDecode(line);
      return json is Map<String, Object?> ? JobMetrics.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }
}

/// Starts per-job measurements: `start` → (thermal events) → `finish`.
class JobMetricsRecorder {
  JobMetricsRecorder({
    required this.store,
    this.clock = const SystemClock(),
    this.battery = const UnavailableBatteryProbe(),
    this.memory = const ProcessMemoryProbe(),
  });

  final MetricsStore store;
  final Clock clock;
  final BatteryProbe battery;
  final MemoryProbe memory;

  Future<JobMetricsSession> start(String jobId, String step) async =>
      JobMetricsSession._(
        this,
        jobId: jobId,
        step: step,
        startedAt: clock.now(),
        batteryStart: await battery.levelPercent(),
      );
}

/// An in-flight measurement; see [JobMetricsRecorder.start].
class JobMetricsSession {
  JobMetricsSession._(
    this._recorder, {
    required this.jobId,
    required this.step,
    required this.startedAt,
    required this.batteryStart,
  });

  final JobMetricsRecorder _recorder;
  final String jobId;
  final String step;
  final DateTime startedAt;
  final int? batteryStart;
  final _thermal = <String>[];

  /// Records a thermal state transition (consecutive duplicates collapse).
  void thermalState(String state) {
    if (_thermal.isEmpty || _thermal.last != state) _thermal.add(state);
  }

  /// Completes the measurement and stores it.
  Future<JobMetrics> finish({
    Duration? audioDuration,
    int? promptTokens,
    Duration? prefillTime,
    int? generatedTokens,
    Duration? decodeTime,
  }) async {
    final metrics = JobMetrics(
      jobId: jobId,
      step: step,
      startedAt: startedAt,
      wallTime: _recorder.clock.now().difference(startedAt),
      audioDuration: audioDuration,
      promptTokens: promptTokens,
      prefillTime: prefillTime,
      generatedTokens: generatedTokens,
      decodeTime: decodeTime,
      peakRssBytes: _recorder.memory.peakRssBytes(),
      batteryStartPercent: batteryStart,
      batteryEndPercent: await _recorder.battery.levelPercent(),
      thermalStates: List.unmodifiable(_thermal),
    );
    await _recorder.store.add(metrics);
    return metrics;
  }
}
