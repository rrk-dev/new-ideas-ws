import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/data/processing_monitor.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/local_notifier.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';
import 'package:vaultvoice/features/pipeline/domain/throughput.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_texts.dart';

part 'processing_providers.g.dart';

/// Local notifications. Default: shows nothing; `bootstrap` overrides it
/// with `FlutterLocalNotifier` on iOS/Android, tests with a fake.
@Riverpod(keepAlive: true)
LocalNotifier localNotifications(Ref ref) => const NoopLocalNotifier();

@Riverpod(keepAlive: true)
ProcessingNotificationTexts processingNotificationTexts(Ref ref) =>
    const EnglishProcessingNotificationTexts();

/// The UI-isolate job observer (throughput, notifications, deep links).
/// Created on first use; `ProcessingServicesHost` starts it at app start.
@Riverpod(keepAlive: true)
ProcessingMonitor processingMonitor(Ref ref) {
  final recordings = ref.watch(recordingsRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final monitor = ProcessingMonitor(
    jobs: ref
        .watch(jobsRepositoryProvider)
        .watchAll()
        .map((rows) => [for (final r in rows) jobFromRow(r)]),
    recording: (id) async {
      final row = (await recordings.get(id)).valueOrNull;
      return row == null
          ? null
          : RecordingInfo(
              title: row.title,
              duration: Duration(milliseconds: row.durationMs),
            );
    },
    settings: ref.watch(settingsRepositoryProvider),
    notifier: ref.watch(localNotificationsProvider),
    texts: ref.watch(processingNotificationTextsProvider),
    payloadFor: (id) => RecordingStatusRoute(recordingId: id).location,
    isAllowedPayload: RecordingStatusRoute.isNotificationTarget,
    navigate: (location) => ref.read(appRouterProvider).go(location),
    retry: (jobId) async {
      try {
        final client = await ref.read(pipelineClientProvider.future);
        await client.retry(jobId);
      } on Object catch (e) {
        logger.warning(
          'pipeline',
          'notification retry failed',
          fields: {'job': LogId(jobId), 'type': LogId('${e.runtimeType}')},
        );
      }
    },
  );
  ref.onDispose(monitor.dispose);
  return monitor;
}

/// Wall-clock ticks so ETAs count down between job updates.
@riverpod
Stream<DateTime> processingNow(Ref ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 15),
    (_) => clock.now(),
  );
}

/// Measured per-step throughput of this device (`settings`).
@riverpod
Stream<ThroughputStats> throughputStats(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(ThroughputStats.settingsKey)
    .map(ThroughputStats.fromJson);

/// Title + length of every recording, by id.
@riverpod
Stream<Map<String, RecordingFacts>> recordingFacts(Ref ref) => ref
    .watch(recordingsRepositoryProvider)
    .watchAll()
    .map(
      (rows) => {
        for (final r in rows)
          r.id: RecordingFacts(
            title: r.title,
            duration: Duration(milliseconds: r.durationMs),
          ),
      },
    );

/// Progress views of every job, in queue order.
@riverpod
Future<List<JobProgressView>> processingViews(Ref ref) async {
  final jobs = await ref.watch(pipelineJobsProvider.future);
  final facts = await ref.watch(recordingFactsProvider.future);
  final stats = await ref.watch(throughputStatsProvider.future);
  final now = await ref.watch(processingNowProvider.future);
  final monitor = ref.watch(processingMonitorProvider);
  return buildProgressViews(
    jobs: jobs,
    recordings: facts,
    stats: stats,
    now: now,
    stepStart: monitor.stepStart,
  );
}
