import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/processing_monitor.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/local_notifier.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';
import 'package:vaultvoice/features/pipeline/domain/throughput.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_texts.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_local_notifier.dart';

const texts = EnglishProcessingNotificationTexts();

void main() {
  group('composeProcessingNotification', () {
    JobSnapshot j(JobState s) => JobSnapshot(
      id: 'job-1',
      recordingId: 'rec-1',
      state: s,
      step: PipelineStepId.write,
      createdAt: t0,
      updatedAt: t0,
    );

    ProcessingNotification? compose(
      JobState? prev,
      JobState now, {
      bool details = false,
    }) => composeProcessingNotification(
      previous: prev,
      job: j(now),
      recordingTitle: 'Meeting with Dana',
      showDetails: details,
      texts: texts,
      payload: const RecordingStatusRoute(recordingId: 'rec-1').location,
    );

    test('[APP-04/AC1] generic lock-screen text by default; title only when '
        'opted in', () {
      final generic = compose(JobState.writing, JobState.done)!;
      expect(generic.kind, ProcessingNotificationKind.noteReady);
      expect(generic.title, 'Your note is ready');
      expect('${generic.title} ${generic.body}', isNot(contains('Dana')));
      expect(generic.revealsContent, isFalse);
      expect(generic.payload, '/library/recordings/rec-1');

      final detailed = compose(JobState.writing, JobState.done, details: true)!;
      expect(detailed.title, 'Note ready — Meeting with Dana');
      expect(detailed.revealsContent, isTrue);
    });

    test('failures carry a Retry action; other transitions are silent', () {
      final failed = compose(JobState.extracting, JobState.failed)!;
      expect(failed.kind, ProcessingNotificationKind.failed);
      expect(failed.actions, [(NotificationActions.retry, 'Retry')]);
      expect(failed.title, isNot(contains('Dana')));
      expect(compose(null, JobState.done), isNull); // seen after restart
      expect(compose(JobState.done, JobState.done), isNull);
      expect(compose(JobState.queued, JobState.transcribing), isNull);
      expect(compose(JobState.extracting, JobState.waiting), isNull);
    });

    test('notification ids are stable and positive', () {
      expect(notificationIdFor('job-1'), notificationIdFor('job-1'));
      expect(notificationIdFor('job-1'), isNot(notificationIdFor('job-2')));
      expect(notificationIdFor('job-1'), greaterThanOrEqualTo(0));
    });
  });

  group('deep-link allowlist', () {
    test('[APP-04/AC1] only processing routes are followed', () {
      bool ok(String s) => RecordingStatusRoute.isNotificationTarget(s);
      expect(
        ok(const RecordingStatusRoute(recordingId: 'abc-1').location),
        isTrue,
      );
      expect(ok(const ProcessingQueueRoute().location), isTrue);
      expect(ok('/record'), isFalse); // never starts recording (SEC-09)
      expect(ok('/settings'), isFalse);
      expect(ok('https://evil.example/library/processing'), isFalse);
      expect(ok('/library/recordings/a?start=1'), isFalse);
      expect(ok('/library/recordings/../record'), isFalse);
      expect(ok('/library/recordings/a/b'), isFalse);
    });
  });

  group('ProcessingMonitor', () {
    late VaultVoiceDatabase db;
    late FakeLocalNotifier notifier;
    late List<String> navigated;
    late List<String> retried;
    late ProcessingMonitor monitor;

    ProcessingMonitor build({NotificationTap? launch}) {
      notifier = FakeLocalNotifier(launch: launch);
      navigated = [];
      retried = [];
      final m = ProcessingMonitor(
        jobs: db.jobsRepository.watchAll().map(
          (rows) => [for (final r in rows) jobFromRow(r)],
        ),
        recording: (id) async {
          final row = (await db.recordingsRepository.get(id)).valueOrNull;
          return row == null
              ? null
              : RecordingInfo(
                  title: row.title,
                  duration: Duration(milliseconds: row.durationMs),
                );
        },
        settings: db.settingsRepository,
        notifier: notifier,
        texts: texts,
        payloadFor: (id) => RecordingStatusRoute(recordingId: id).location,
        isAllowedPayload: RecordingStatusRoute.isNotificationTarget,
        navigate: navigated.add,
        retry: (id) async => retried.add(id),
      );
      addTearDown(m.dispose);
      return m;
    }

    Future<void> put(
      JobState state,
      PipelineStepId step, {
      required int atSec,
      double progress = 0,
    }) async {
      final job = JobSnapshot(
        id: 'job-1',
        recordingId: 'rec-1',
        state: state,
        step: step,
        progress: progress,
        createdAt: t0,
        updatedAt: t0.add(Duration(seconds: atSec)),
        failureKind: state == JobState.failed ? FailureKind.permanent : null,
      );
      final existing = await db.jobsRepository.get('job-1');
      if (existing.isOk) {
        expectOk(
          await db.jobsRepository.updateFields('job-1', jobToCompanion(job)),
        );
      } else {
        expectOk(await db.jobsRepository.create(jobToCompanion(job)));
      }
      await pumpEventQueue();
      await monitor.settled;
    }

    setUp(() async {
      db = memoryDb();
      await seedRecording(db, 'rec-1');
      expectOk(
        await db.recordingsRepository.updateFields(
          'rec-1',
          const RecordingsCompanion(
            title: Value('Meeting with Dana'),
            durationMs: Value(100000),
          ),
        ),
      );
    });

    test('[APP-04/AC1] note-ready notification deep-links to the recording; '
        'throughput is measured and persisted', () async {
      monitor = build();
      await monitor.start();
      await pumpEventQueue();
      await put(JobState.queued, PipelineStepId.transcribe, atSec: 0);
      expect(notifier.permissionRequests, 1, reason: 'asked just-in-time');
      await put(JobState.transcribing, PipelineStepId.transcribe, atSec: 0);
      await put(
        JobState.transcribing,
        PipelineStepId.transcribe,
        progress: 0.5,
        atSec: 20,
      );
      await put(JobState.transcribed, PipelineStepId.extract, atSec: 40);
      await put(JobState.extracting, PipelineStepId.extract, atSec: 40);
      await put(JobState.extracted, PipelineStepId.render, atSec: 70);
      await put(JobState.rendering, PipelineStepId.render, atSec: 70);
      await put(JobState.rendered, PipelineStepId.write, atSec: 71);
      await put(JobState.writing, PipelineStepId.write, atSec: 71);
      await put(JobState.done, PipelineStepId.write, progress: 1, atSec: 72);

      expect(notifier.shown, hasLength(1));
      final n = notifier.shown.single;
      expect(n.kind, ProcessingNotificationKind.noteReady);
      expect(n.title, 'Your note is ready'); // generic by default
      expect(n.payload, '/library/recordings/rec-1');

      final stats = ThroughputStats.fromJson(
        (await db.settingsRepository.get(ThroughputStats.settingsKey))
            .valueOrNull,
      );
      // 40 s for 100 s of audio → RTF 0.4; extraction 30 s → 0.3.
      expect(stats[PipelineStepId.transcribe]!.factor, closeTo(0.4, 1e-9));
      expect(stats[PipelineStepId.extract]!.factor, closeTo(0.3, 1e-9));

      notifier.tap(n);
      await pumpEventQueue();
      expect(navigated, ['/library/recordings/rec-1']);
    });

    test('[APP-04/AC1] failure notification Retry action retries the job and '
        'opens the recording', () async {
      monitor = build();
      await monitor.start();
      await put(JobState.extracting, PipelineStepId.extract, atSec: 0);
      await put(JobState.failed, PipelineStepId.extract, atSec: 5);
      final n = notifier.shown.single;
      expect(n.kind, ProcessingNotificationKind.failed);
      notifier.tap(n, actionId: NotificationActions.retry);
      await pumpEventQueue();
      expect(retried, ['job-1']);
      expect(navigated, ['/library/recordings/rec-1']);
    });

    test('[APP-04/AC1] a notification that launched the app is followed; '
        'foreign payloads are ignored', () async {
      monitor = build(
        launch: const NotificationTap(payload: '/library/recordings/rec-1'),
      );
      await monitor.start();
      expect(navigated, ['/library/recordings/rec-1']);
      await monitor.handleTap(const NotificationTap(payload: '/record'));
      await monitor.handleTap(
        const NotificationTap(payload: 'vaultvoice://record?start=1'),
      );
      expect(navigated, hasLength(1));
    });

    test('details setting includes the title; disabled setting posts '
        'nothing; existing jobs at startup are not announced', () async {
      await put0(db, JobState.done);
      expectOk(
        await db.settingsRepository.set(
          SettingKeys.notificationsShowDetails,
          true,
        ),
      );
      monitor = build();
      await monitor.start();
      await pumpEventQueue();
      await monitor.settled;
      expect(notifier.shown, isEmpty, reason: 'already done before start');
      expect(notifier.permissionRequests, 0);

      await put(JobState.writing, PipelineStepId.write, atSec: 1);
      await put(JobState.done, PipelineStepId.write, atSec: 2);
      expect(notifier.shown.single.title, 'Note ready — Meeting with Dana');
      expect(notifier.shown.single.revealsContent, isTrue);

      expectOk(
        await db.settingsRepository.set(
          SettingKeys.notificationsEnabled,
          false,
        ),
      );
      await put(JobState.writing, PipelineStepId.write, atSec: 3);
      await put(JobState.done, PipelineStepId.write, atSec: 4);
      expect(notifier.shown, hasLength(1));
    });
  });
}

Future<void> put0(VaultVoiceDatabase db, JobState state) async {
  expectOk(
    await db.jobsRepository.create(
      jobToCompanion(
        JobSnapshot(
          id: 'job-1',
          recordingId: 'rec-1',
          state: state,
          step: PipelineStepId.write,
          createdAt: t0,
          updatedAt: t0,
        ),
      ),
    ),
  );
}
