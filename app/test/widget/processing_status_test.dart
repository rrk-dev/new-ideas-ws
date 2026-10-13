import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_indicator.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_status_card.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_texts.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';

import '../helpers/processing_fixtures.dart';

List<Override> viewsOverride(Future<List<JobProgressView>> Function() views) =>
    [
      flavorProvider.overrideWithValue(Flavor.dev),
      processingViewsProvider.overrideWith((ref) => views()),
    ];

Future<ProviderContainer> pumpApp(
  WidgetTester t,
  List<JobProgressView> views,
) async {
  final container = ProviderContainer(
    overrides: viewsOverride(() async => views),
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await t.pumpAndSettle();
  return container;
}

Future<void> pumpScreen(
  WidgetTester t,
  Widget screen,
  Future<List<JobProgressView>> Function() views,
) async {
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: viewsOverride(views),
      child: MaterialApp(home: screen),
    ),
  );
}

Future<void> expectAccessible(WidgetTester t) async {
  await expectLater(t, meetsGuideline(textContrastGuideline));
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
  await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  testWidgets('[APP-04/AC1] notification payload deep-links through the typed '
      'router to the recording status (same Dart routing on iOS + Android)', (
    t,
  ) async {
    final container = await pumpApp(t, sampleQueue());
    // The payload the monitor puts in every notification for recording a.
    const payload = RecordingStatusRoute(recordingId: 'rec-a');
    expect(payload.location, '/library/recordings/rec-a');
    container.read(appRouterProvider).go(payload.location);
    await t.pumpAndSettle();
    expect(find.byType(RecordingStatusScreen), findsOneWidget);
    expect(find.text('Weekly planning'), findsOneWidget);
    expect(find.text('Transcribing'), findsOneWidget);
    // Back goes to the Library tab, not out of the app.
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byType(RecordingStatusScreen), findsNothing);
  });

  testWidgets('global queue indicator counts the queue and opens it', (
    t,
  ) async {
    await pumpApp(t, sampleQueue());
    final indicator = find.byType(ProcessingQueueIndicator);
    expect(
      find.descendant(
        of: indicator,
        matching: find.text('Processing 3 recordings · 1 needs attention'),
      ),
      findsOneWidget,
    );
    await t.tap(indicator);
    await t.pumpAndSettle();
    expect(find.byType(ProcessingQueueScreen), findsOneWidget);
    expect(find.text('Weekly planning'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Design review'), 200);
    expect(find.text('Design review'), findsOneWidget);
    await expectAccessible(t);
  });

  testWidgets('global queue indicator is hidden when nothing is queued', (
    t,
  ) async {
    await pumpApp(t, [
      progressView(id: 'x', state: JobState.done, step: PipelineStepId.write),
    ]);
    expect(find.textContaining('Processing'), findsNothing);
  });

  group('ProcessingStatusCard', () {
    Future<void> pumpCard(WidgetTester t, JobProgressView v) => t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProcessingStatusCard(
            view: v,
            onCancel: () {},
            onRetry: () {},
            onProcessNow: () {},
          ),
        ),
      ),
    );

    testWidgets('running: step, percent, ETA, cancel', (t) async {
      await pumpCard(t, sampleQueue()[0]);
      expect(find.text('Transcribing'), findsOneWidget);
      expect(find.text('10% · About 4 min left'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.bySemanticsLabel('Transcribing, 10 percent'), findsOneWidget);
    });

    testWidgets('queued: position and process now', (t) async {
      await pumpCard(t, sampleQueue()[1]);
      expect(find.text('Queued'), findsOneWidget);
      expect(
        find.text('0% · About 12 min left · Position 2 in queue'),
        findsOneWidget,
      );
      expect(find.text('Process now'), findsOneWidget);
    });

    testWidgets('waiting, failed and done states', (t) async {
      await pumpCard(t, sampleQueue()[2]);
      expect(find.text('Waiting for a model download'), findsOneWidget);
      expect(find.text('Untitled recording'), findsOneWidget);
      await pumpCard(t, sampleQueue()[3]);
      expect(find.text('Processing failed — you can retry'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await pumpCard(
        t,
        progressView(id: 'z', state: JobState.done, step: PipelineStepId.write),
      );
      expect(find.text('Note ready'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('screens: loading / empty / error', () {
    testWidgets('recording status', (t) async {
      await pumpScreen(
        t,
        const RecordingStatusScreen(recordingId: 'rec-nope'),
        () async => sampleQueue(),
      );
      await t.pump();
      expect(
        find.text('This recording has not been processed yet.'),
        findsOneWidget,
      );
      await pumpScreen(
        t,
        const RecordingStatusScreen(recordingId: 'rec-a'),
        () => Future.error(StateError('db')),
      );
      await t.pump();
      await t.pump();
      expect(
        find.text('Could not load the processing status.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('queue', (t) async {
      await pumpScreen(
        t,
        const ProcessingQueueScreen(),
        () => Future.delayed(const Duration(seconds: 1), () => const []),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.text('Nothing is being processed right now.'),
        findsOneWidget,
      );
      await expectAccessible(t);
    });

    test('currentViewFor prefers the job still in the pipeline', () {
      final views = [
        progressView(id: 'old', state: JobState.done, createdMinute: 0),
        progressView(id: 'new', state: JobState.queued, createdMinute: 5),
      ];
      // Same recording for both.
      final fixed = [
        for (final v in views)
          JobProgressView(
            job: JobSnapshot(
              id: v.job.id,
              recordingId: 'r',
              state: v.job.state,
              step: v.job.step,
              createdAt: v.job.createdAt,
              updatedAt: v.job.updatedAt,
            ),
            recordingTitle: '',
          ),
      ];
      expect(currentViewFor(fixed, 'r')!.job.id, 'new');
      expect(currentViewFor(fixed.sublist(0, 1), 'r')!.job.id, 'old');
    });
  });

  test('etaLabel formatting', () {
    expect(etaLabel(null), 'Estimating time…');
    expect(etaLabel(const Duration(seconds: 20)), 'Less than a minute left');
    expect(
      etaLabel(const Duration(minutes: 3, seconds: 10)),
      'About 3 min left',
    );
    expect(etaLabel(const Duration(minutes: 120)), 'About 2 h left');
    expect(etaLabel(const Duration(minutes: 65)), 'About 1 h 5 min left');
  });
}
