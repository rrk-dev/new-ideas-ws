import 'dart:async';

import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart'
    show userPriority;
import 'package:vaultvoice/features/pipeline/domain/background_platform.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_conditions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Settings key: ids of jobs this guard paused (so it never resumes a job
/// the user paused). JSON list of strings.
const String kAutoPausedJobsKey = 'pipeline.auto_paused';

/// Generic texts of the ongoing processing notification (content-free).
typedef ProcessingKeepAliveTexts = ({String title, String text});

/// UI-isolate guardrails around the pipeline worker (FND-08,
/// vv-background-execution):
///
/// - holds the OS keep-alive while work is pending
///   ([BackgroundProcessingPlatform.beginProcessing]: iOS background task,
///   Android foreground service + progress) and releases it when idle;
/// - pauses jobs (= checkpoint) when processing must stop — thermal
///   critical/serious, Low Power Mode, "Process only while charging" without
///   a charger, or the OS background budget expiring — and resumes exactly
///   those jobs when the reason clears ("Process now" overrides the power
///   settings, never thermal-critical or an expired budget);
/// - schedules deferred processing (iOS `BGProcessingTask`) when the app
///   leaves the foreground with work pending, and completes it when idle;
/// - starts the worker when runnable jobs exist (so jobs left by a kill are
///   recovered at launch).
///
/// GPU use while backgrounded is handled by the worker's backend policy
/// (FND-11 `PipelineConditions.setForeground`: CPU in the background, a
/// running GPU generation restarts on the CPU).
class BackgroundProcessingGuard {
  BackgroundProcessingGuard({
    required this.platform,
    required this.jobs,
    required this.client,
    required this.settings,
    required this.texts,
    bool foreground = true,
  }) : _isForeground = foreground;

  final BackgroundProcessingPlatform platform;
  final Stream<List<JobSnapshot>> jobs;

  /// The worker client; calling it starts the worker.
  final Future<PipelineClient> Function() client;
  final SettingsRepository settings;
  final ProcessingKeepAliveTexts texts;

  bool _isForeground;
  bool _expired = false;
  bool _deferredRunning = false;
  bool _keepAlive = false;
  int? _lastPercent;
  DeviceConditions _conditions = const DeviceConditions();
  List<JobSnapshot> _jobs = const [];
  final List<StreamSubscription<Object?>> _subs = [];
  Future<void> _queue = Future.value();
  bool _started = false;
  bool _disposed = false;

  /// Current device conditions (diagnostics/tests).
  DeviceConditions get conditions => _conditions;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _conditions = await platform.conditions();
    } on Object {
      // keep the safe default (not charging, thermal unknown)
    }
    _subs
      ..add(platform.events.listen(_onEvent))
      ..add(
        jobs.listen((j) {
          _jobs = j;
          _schedule();
        }),
      )
      ..add(
        settings.watch(SettingKeys.processingChargeOnly).listen((_) {
          _schedule();
        }),
      );
  }

  /// App lifecycle (from `ProcessingServicesHost`).
  void setForeground({required bool foreground}) {
    if (_isForeground == foreground) return;
    _isForeground = foreground;
    if (foreground) {
      // Back in front: the OS budget is fresh again.
      _expired = false;
    } else if (_pending.isNotEmpty) {
      unawaited(_guard(platform.scheduleDeferred));
    }
    _schedule();
  }

  /// Completes when all scheduled evaluations ran (tests).
  Future<void> settled() => _queue;

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    await _queue;
  }

  void _onEvent(BackgroundEvent event) {
    switch (event) {
      case ConditionsChanged(:final conditions):
        _conditions = conditions;
      case BackgroundTimeExpiring():
        _expired = true;
      case DeferredProcessingStarted():
        _expired = false;
        _deferredRunning = true;
    }
    _schedule();
  }

  void _schedule() {
    if (_disposed) return;
    _queue = _queue.then((_) => _guard(_evaluate));
  }

  /// Jobs that still have work (not terminal, not waiting for the user).
  List<JobSnapshot> get _pending => [
    for (final j in _jobs)
      if (!j.state.isTerminal && j.state != JobState.waiting) j,
  ];

  Future<void> _evaluate() async {
    if (_disposed) return;
    final chargeOnly =
        (await settings.get(SettingKeys.processingChargeOnly)).valueOrNull ==
        true;
    final autoPaused = await _autoPaused();
    final before = Set.of(autoPaused);
    final running = <JobSnapshot>[];
    PipelineClient? worker;
    Future<PipelineClient> w() async => worker ??= await client();

    for (final job in _pending) {
      final hold = holdReason(
        _conditions,
        chargeOnly: chargeOnly,
        userForced: job.priority >= userPriority,
        backgroundExpired: _expired,
      );
      if (job.state == JobState.paused) {
        if (hold == null && autoPaused.contains(job.id)) {
          if ((await (await w()).resume(job.id)).isOk) {
            autoPaused.remove(job.id);
            running.add(job);
          }
        }
        continue;
      }
      if (hold != null) {
        // Already paused by us (the job snapshot may lag behind).
        if (autoPaused.contains(job.id)) continue;
        if ((await (await w()).pause(job.id)).isOk) autoPaused.add(job.id);
      } else {
        running.add(job);
      }
    }
    // Forget jobs that finished or were cancelled meanwhile.
    final open = {for (final j in _pending) j.id};
    autoPaused.removeWhere((id) => !open.contains(id));
    if (autoPaused.length != before.length || !autoPaused.containsAll(before)) {
      await settings.set(kAutoPausedJobsKey, autoPaused.toList()..sort());
    }

    if (running.isNotEmpty) {
      await w(); // make sure the worker runs (recovery after a kill)
      if (!_keepAlive) {
        _lastPercent = null;
        await platform.beginProcessing(title: texts.title, text: texts.text);
        _keepAlive = true;
      }
      final active = running.where((j) => j.state.isActive).toList();
      final percent = active.isEmpty
          ? 0
          : (active.first.progress * 100).round().clamp(0, 100);
      if (percent != _lastPercent) {
        _lastPercent = percent;
        await platform.updateProgress(percent);
      }
    } else {
      if (_keepAlive) {
        _keepAlive = false;
        await platform.endProcessing();
      }
      if (_deferredRunning) {
        _deferredRunning = false;
        // Success only when nothing is left for later.
        await platform.completeDeferred(success: autoPaused.isEmpty);
      }
    }
  }

  Future<Set<String>> _autoPaused() async {
    final raw = (await settings.get(kAutoPausedJobsKey)).valueOrNull;
    return {
      if (raw is List)
        for (final id in raw)
          if (id is String) id,
    };
  }

  /// Platform/worker errors never break the guard (next event retries).
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // content-free policy: nothing to log here
    }
  }
}
