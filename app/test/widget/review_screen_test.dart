import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/transcript_lines_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/review/data/review_providers.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/library_fixtures.dart';
import '../helpers/processing_fixtures.dart';
import '../unit/templates/template_fixtures.dart';

final AppLocalizations _l = lookupAppLocalizations(kFallbackLocale);

final ExtractionView _extraction = ExtractionView(
  id: 'e1',
  profileId: 'meeting',
  profileVersion: 1,
  modelId: 'qwen',
  valid: true,
  createdAt: libraryT0,
  data: const {
    'title': 'API sync',
    'summary': 'The team discussed the API.',
    'attendees': ['Prya'],
    'decisions': <Object?>[],
    'action_items': [
      {'task': 'Update SDK', 'owner': null, 'due': null, 't': '00:00:12'},
    ],
    'open_questions': <Object?>[],
    'topics': <Object?>[],
  },
);

class _Navigator implements TranscriptNavigator {
  final opened = <({String id, int? atMs})>[];

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      opened.add((id: recordingId, atMs: atMs));
}

class _Review implements ReviewService {
  final approved = <Map<String, Object?>>[];
  final jobs = <JobSnapshot?>[];
  final modes = <String, bool>{};

  @override
  Future<Result<void>> approveAndExport({
    required String extractionId,
    required Map<String, Object?> edited,
    required bool valid,
    required JobSnapshot? job,
  }) async {
    approved.add(edited);
    jobs.add(job);
    return const Ok(null);
  }

  @override
  Future<Result<String>> preview({
    required String recordingId,
    required String extractionId,
    required Map<String, Object?> edited,
    required NoteRenderer renderer,
  }) async => Ok('PREVIEW ${edited['attendees']}');

  @override
  Future<Result<void>> setMode(String profileId, {required bool review}) async {
    modes[profileId] = review;
    return const Ok(null);
  }
}

Future<ProviderContainer> _pump(
  WidgetTester t,
  String location, {
  _Review? review,
  TranscriptNavigator? navigator,
  bool waitingForReview = false,
}) async {
  t.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final container = ProviderContainer(
    overrides: [
      flavorProvider.overrideWithValue(Flavor.prod),
      settingsStoreProvider.overrideWithValue(
        FakeSettingsStore({OnboardingKeys.completed: true}),
      ),
      storagePathsProvider.overrideWith(
        (ref) => Completer<StoragePaths>().future,
      ),
      processingViewsProvider.overrideWith(
        (ref) async => [
          if (waitingForReview)
            progressView(
              id: 'a',
              state: JobState.waiting,
              step: PipelineStepId.render,
              waitingReason: WaitingReason.review,
            ),
        ],
      ),
      ...libraryOverrides(extraction: _extraction),
      reviewProfileProvider('meeting')
          .overrideWith((ref) async => builtinProfiles['meeting']),
      reviewProfilesProvider.overrideWith(
        (ref) => Stream.value(builtinProfiles.all),
      ),
      previewRendererProvider.overrideWith(
        (ref) async => TemplateNoteRenderer(
          profiles: builtinProfiles,
          templates: builtinTemplates,
          appVersion: '1.0.0',
        ).call,
      ),
      reviewServiceProvider.overrideWithValue(review ?? _Review()),
      if (navigator != null)
        transcriptNavigatorProvider.overrideWithValue(navigator),
    ],
  );
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(location);
  await t.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await t.pumpAndSettle();
  return container;
}

Finder _field(String path) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.endsWith('-$path') &&
      (w.key! as ValueKey<String>).value.startsWith('field-'),
);

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(
    f,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('review-form')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('[APP-05/AC1] the source link of an item jumps to its '
      'timestamp (navigator gets the audio position)', (t) async {
    final nav = _Navigator();
    await _pump(t, '/library/recordings/rec-a/review', navigator: nav);
    final link = find.byKey(const ValueKey('source-link-00:00:12'));
    await _scrollTo(t, link);
    await t.tap(link);
    expect(nav.opened.single, (id: 'rec-a', atMs: 12000));
  });

  testWidgets('[APP-05/AC1] lines navigation opens the transcript at that '
      'position with the line highlighted', (t) async {
    // Integration W3: production uses the STT-06 viewer (see below); the
    // APP-02 lines view stays available as LinesTranscriptNavigator.
    expect(
      ProviderContainer().read(transcriptNavigatorProvider),
      isA<PlaybackTranscriptNavigator>(),
    );
    await _pump(
      t,
      '/library/recordings/rec-a/review',
      navigator: const LinesTranscriptNavigator(),
    );
    final link = find.byKey(const ValueKey('source-link-00:00:12'));
    await _scrollTo(t, link);
    await t.tap(link);
    await t.pumpAndSettle();
    final tiles = t
        .widgetList<TranscriptLineTile>(find.byType(TranscriptLineTile))
        .toList();
    final lit = tiles.where((l) => l.highlighted).single;
    expect(lit.line.startMs, 12000);
    expect(timestampToMs('00:00:12'), 12000);
  });

  testWidgets('[APP-05/AC1] form edits (text, add, remove) are what gets '
      'exported; the preview renders the edits', (t) async {
    final review = _Review();
    await _pump(
      t,
      '/library/recordings/rec-a/review',
      review: review,
      waitingForReview: true,
    );
    // Fix the misspelt attendee and add one.
    await t.enterText(_field('attendees.0'), 'Priya');
    await t.pumpAndSettle();
    await _scrollTo(t, find.byKey(const ValueKey('add-attendees')));
    await t.tap(find.byKey(const ValueKey('add-attendees')));
    await t.pumpAndSettle();
    await t.enterText(_field('attendees.1'), 'Sam');
    await t.pumpAndSettle();
    // Owner of the action item.
    await _scrollTo(t, _field('action_items.0.owner'));
    await t.enterText(_field('action_items.0.owner'), 'Sam');
    await t.pumpAndSettle();

    await t.tap(find.text(_l.reviewTabPreview));
    await t.pumpAndSettle();
    expect(find.text('PREVIEW [Priya, Sam]'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('review-export')));
    await t.pumpAndSettle();
    final edited = review.approved.single;
    expect(edited['attendees'], ['Priya', 'Sam']);
    final items = edited['action_items']! as List<Object?>;
    expect((items.single! as Map)['owner'], 'Sam');
    expect((items.single! as Map)['t'], '00:00:12');
    expect(review.jobs.single?.waitingReason, WaitingReason.review);
    expect(find.text(_l.reviewExported), findsOneWidget);
  });

  testWidgets('[APP-05] the detail shows a review banner while the job '
      'waits for review', (t) async {
    final c = await _pump(
      t,
      '/library/recordings/rec-a',
      waitingForReview: true,
    );
    expect(find.byKey(const ValueKey('recording-review-banner')), findsOne);
    await t.tap(find.text(_l.reviewOpen));
    await t.pumpAndSettle();
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/library/recordings/rec-a/review',
    );
  });

  testWidgets('[APP-05] per-profile setting: auto-export vs review-first', (
    t,
  ) async {
    final review = _Review();
    await _pump(t, '/settings/review', review: review);
    expect(find.text('Meeting Action Items'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-mode-meeting')));
    await t.pumpAndSettle();
    expect(review.modes, {'meeting': true});
  });

  for (final route in [
    '/library/recordings/rec-a/review',
    '/settings/review',
  ]) {
    testWidgets('[APP-06/AC1] $route: labelled controls, tap targets, '
        'contrast', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, route);
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
