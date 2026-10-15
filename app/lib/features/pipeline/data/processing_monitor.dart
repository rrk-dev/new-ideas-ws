import 'dart:async';

import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/features/pipeline/domain/eta.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/local_notifier.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';
import 'package:vaultvoice/features/pipeline/domain/throughput.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// What the monitor needs to know about a recording. The title is user
/// content: it is only used for opted-in notification text, never logged.
class RecordingInfo {
  const RecordingInfo({required this.title, required this.duration});

  final String title;
  final Duration duration;
}

/// UI-isolate observer of the `jobs` table (APP-04):
/// * measures each finished step run and folds it into the persisted
///   [ThroughputStats] (ETA input);
/// * posts a local notification when a job enters `done` or `failed`;
/// * asks for the notification permission once, just-in-time, when the
///   first new job appears while the app is in use;
/// * routes notification taps (typed-route payloads) and the "Retry" action.
///
/// It reads only ids, states, numbers and — when the user enabled
/// notification details — the recording title.
class ProcessingMonitor {
  ProcessingMonitor({
    required this.jobs,
    required this.recording,
    required this.settings,
    required this.notifier,
    required this.texts,
    required this.payloadFor,
    required this.isAllowedPayload,
    required this.navigate,
    required this.retry,
  });

  /// Every job, in queue order (drift stream on `jobs`).
  final Stream<List<JobSnapshot>> jobs;

  /// Looks up a recording's title and length.
  final Future<RecordingInfo?> Function(String recordingId) recording;
  final SettingsRepository settings;
  final LocalNotifier notifier;
  final ProcessingNotificationTexts texts;

  /// Typed-route location of a recording's status screen.
  final String Function(String recordingId) payloadFor;

  /// Deep-link allowlist: only payloads this app produces are followed.
  final bool Function(String payload) isAllowedPayload;
  final void Function(String location) navigate;

  /// Retries a failed job (user tapped "Retry" in a notification).
  final Future<void> Function(String jobId) retry;

  final ThroughputObserver observer = ThroughputObserver();
  final Map<String, JobState> _last = {};
  final Map<String, JobSnapshot> _latest = {};
  StreamSubscription<List<JobSnapshot>>? _sub;
  Future<void> _pending = Future.value();
  bool _seeded = false;
  final Completer<void> _firstSnapshot = Completer<void>();
  bool _started = false;

  /// Starts observing; also follows a notification tap that launched the app.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await notifier.initialize(texts: texts, onTap: handleTap);
    final launch = await notifier.launchTap();
    _sub = jobs.listen(
      (list) => _pending = _pending.then((_) => _onJobs(list)),
      onError: (Object _) {
        // DB unavailable: show nothing, never crash
        if (!_firstSnapshot.isCompleted) _firstSnapshot.complete();
      },
    );
    if (launch != null) await handleTap(launch);
  }

  /// Completes when every snapshot received so far has been processed.
  Future<void> get settled => _pending;

  Future<void> dispose() async {
    await _sub?.cancel();
    await _pending;
  }

  /// When [jobId]'s current step started, and at which progress (live ETA).
  (DateTime?, double) stepStart(String jobId) =>
      (observer.stepStartedAt(jobId), observer.stepStartProgress(jobId));

  Future<void> handleTap(NotificationTap tap) async {
    if (!isAllowedPayload(tap.payload)) return;
    if (tap.actionId == NotificationActions.retry) {
      final recordingId = Uri.parse(tap.payload).pathSegments.last;
      // A cold start delivers the tap before the first jobs snapshot.
      await _firstSnapshot.future;
      await _pending;
      for (final job in _latest.values) {
        if (job.recordingId == recordingId && job.state == JobState.failed) {
          await retry(job.id);
        }
      }
    }
    navigate(tap.payload);
  }

  Future<void> _onJobs(List<JobSnapshot> jobs) async {
    final firstSnapshot = !_seeded;
    _seeded = true;
    var newJob = false;
    for (final job in jobs) {
      final previous = _last[job.id];
      if (!firstSnapshot && previous == null && !job.state.isTerminal) {
        newJob = true;
      }
      _last[job.id] = job.state;
      _latest[job.id] = job;
      if (previous == job.state && !job.state.isActive) continue;
      final info = await recording(job.recordingId);
      final measurement = observer.observe(
        job,
        info?.duration ?? Duration.zero,
      );
      if (measurement != null) await _record(measurement);
      if (!firstSnapshot) await _maybeNotify(previous, job, info);
    }
    final ids = {for (final j in jobs) j.id};
    observer.retain(ids);
    _last.removeWhere((id, _) => !ids.contains(id));
    _latest.removeWhere((id, _) => !ids.contains(id));
    if (!_firstSnapshot.isCompleted) _firstSnapshot.complete();
    if (newJob) await _maybeAskPermission();
  }

  Future<void> _record(StepMeasurement m) async {
    final current = ThroughputStats.fromJson(
      (await settings.get(ThroughputStats.settingsKey)).valueOrNull,
    );
    await settings.set(
      ThroughputStats.settingsKey,
      current.record(m.step, m.factor).toJson(),
    );
  }

  Future<bool> _flag(String key, {required bool fallback}) async {
    final v = (await settings.get(key)).valueOrNull;
    return v is bool ? v : fallback;
  }

  Future<void> _maybeNotify(
    JobState? previous,
    JobSnapshot job,
    RecordingInfo? info,
  ) async {
    if (!await _flag(SettingKeys.notificationsEnabled, fallback: true)) return;
    final n = composeProcessingNotification(
      previous: previous,
      job: job,
      recordingTitle: info?.title,
      showDetails: await _flag(
        SettingKeys.notificationsShowDetails,
        fallback: false,
      ),
      texts: texts,
      payload: payloadFor(job.recordingId),
    );
    if (n != null) await notifier.show(n);
  }

  Future<void> _maybeAskPermission() async {
    if (!await _flag(SettingKeys.notificationsEnabled, fallback: true)) return;
    if (await _flag(
      SettingKeys.notificationsPermissionAsked,
      fallback: false,
    )) {
      return;
    }
    await settings.set(SettingKeys.notificationsPermissionAsked, true);
    await notifier.requestPermission();
  }
}
