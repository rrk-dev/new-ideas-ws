import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/widgets/grouped_card.dart';
import 'package:vaultvoice/features/library/domain/library_grouping.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/library_texts.dart';
import 'package:vaultvoice/features/library/presentation/recording_detail_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_lines_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/library_fixtures.dart';

final AppLocalizations _l = lookupAppLocalizations(kFallbackLocale);

class _Navigator implements TranscriptNavigator {
  final opened = <({String id, int? atMs})>[];

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      opened.add((id: recordingId, atMs: atMs));
}

Future<ProviderContainer> _pump(
  WidgetTester t,
  String location, {
  List<Override> extra = const [],
  List<LibraryItem>? items,
  FakeSearchRepository? search,
  FakeRecordingDeleter? deleter,
  List<ActionItemView> actionItems = const [],
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
      processingViewsProvider.overrideWith((ref) async => const []),
      ...libraryOverrides(
        items: items,
        search: search,
        deleter: deleter,
        actionItems: actionItems,
      ),
      ...extra,
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

String _path(ProviderContainer c) =>
    c.read(appRouterProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('[APP-02] library rows show title, date, duration, profile, '
      'status and export destination; tap opens the detail', (t) async {
    final c = await _pump(t, '/library');
    final a = sampleLibrary().first;
    expect(find.text('Weekly planning'), findsOneWidget);
    expect(
      find.text(
        '${LibraryTexts.date(_l, a.createdAt)} · '
        '${_l.durationMinutesSeconds(23, 5)} · Meeting Action Items',
      ),
      findsOneWidget,
    );
    expect(
      find.text(_l.libraryExportedTo(_l.libraryStatusExported, 'Obsidian')),
      findsOneWidget,
    );
    expect(find.text(_l.libraryStatusProcessing), findsOneWidget);
    expect(find.text(_l.untitledRecording), findsOneWidget);

    await t.tap(find.text('Weekly planning'));
    await t.pumpAndSettle();
    expect(_path(c), '/library/recordings/rec-a');
    expect(find.text('API version decision'), findsOneWidget);
  });

  testWidgets('[APP-02] empty library and no-match states', (t) async {
    await _pump(t, '/library', items: const []);
    expect(find.text(_l.libraryEmpty), findsOneWidget);
  });

  testWidgets('[APP-02] full-text search keeps only hits and shows the '
      'matched snippet', (t) async {
    final search = FakeSearchRepository({
      'budget': [
        const SearchHit(
          recordingId: 'rec-b',
          kind: 'transcript',
          snippet:
              'the $kSnippetOpen'
              'budget$kSnippetClose for repairs',
          rank: -2,
        ),
      ],
    });
    await _pump(t, '/library', search: search);
    await t.enterText(find.byKey(const ValueKey('library-search')), 'budget');
    await t.pumpAndSettle();
    expect(search.queries, contains('budget'));
    expect(find.text('Dishwasher warranty'), findsOneWidget);
    expect(find.text('Weekly planning'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText() == 'the budget for repairs',
      ),
      findsOneWidget,
    );

    await t.enterText(find.byKey(const ValueKey('library-search')), 'zzz');
    await t.pumpAndSettle();
    expect(find.text(_l.libraryNoMatches), findsOneWidget);
  });

  testWidgets('[APP-02] status filter and sort menu', (t) async {
    await _pump(t, '/library');
    await t.tap(find.byKey(const ValueKey('library-filter-status')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(MenuItemButton, _l.libraryStatusFailed));
    await t.pumpAndSettle();
    expect(find.text(_l.untitledRecording), findsOneWidget);
    expect(find.text('Weekly planning'), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('library-filter-clear')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('library-filter-clear')));
    await t.pumpAndSettle();
    expect(find.text('Weekly planning'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('library-sort')));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.librarySortTitle));
    await t.pumpAndSettle();
    final titles = [
      for (final w in t.widgetList<ListTile>(find.byType(ListTile)))
        (w.title! as Text).data!,
    ];
    expect(titles, [
      'Dishwasher warranty',
      'Weekly planning',
      _l.untitledRecording,
    ]);
  });

  testWidgets('[APP-02/AC2] delete asks whether to delete the exported note '
      'too (default: keep it)', (t) async {
    final deleter = FakeRecordingDeleter();
    final c = await _pump(t, '/library/recordings/rec-a', deleter: deleter);
    await t.tap(find.byKey(const ValueKey('recording-actions')));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.recordingDelete));
    await t.pumpAndSettle();
    expect(find.text(_l.recordingDeleteNotes('Obsidian')), findsOneWidget);
    final box = t.widget<CheckboxListTile>(
      find.byKey(const ValueKey('recording-delete-notes')),
    );
    expect(box.value, isFalse);
    await t.tap(find.byKey(const ValueKey('recording-delete-notes')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('recording-delete-confirm')));
    await t.pumpAndSettle();
    expect(deleter.calls.single, (id: 'rec-a', notes: true));
    expect(_path(c), '/library');
    expect(find.text(_l.recordingDeleted), findsOneWidget);
  });

  testWidgets('[APP-02/AC2] delete without the box keeps the note; cancel '
      'deletes nothing', (t) async {
    final deleter = FakeRecordingDeleter();
    await _pump(t, '/library/recordings/rec-a', deleter: deleter);
    Future<void> openDelete() async {
      await t.tap(find.byKey(const ValueKey('recording-actions')));
      await t.pumpAndSettle();
      await t.tap(find.text(_l.recordingDelete));
      await t.pumpAndSettle();
    }

    await openDelete();
    await t.tap(find.text(_l.commonCancel));
    await t.pumpAndSettle();
    expect(deleter.calls, isEmpty);

    await openDelete();
    await t.tap(find.byKey(const ValueKey('recording-delete-confirm')));
    await t.pumpAndSettle();
    expect(deleter.calls.single, (id: 'rec-a', notes: false));
  });

  testWidgets('[APP-02] detail shows transcript preview, extracted fields '
      'and export history; "show transcript" opens the transcript', (t) async {
    final nav = _Navigator();
    await _pump(
      t,
      '/library/recordings/rec-a',
      extra: [transcriptNavigatorProvider.overrideWithValue(nav)],
    );
    expect(find.text('Attendees'), findsOneWidget);
    expect(find.text('Priya\nSam'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Obsidian'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('recording-tab-summary')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Meetings/2026-10-12-planning.md'), findsOne);
    await t.tap(find.text(_l.recordingTabActionItems));
    await t.pumpAndSettle();
    expect(find.text('Update the client SDK · Sam · Friday'), findsOneWidget);
    await t.tap(find.text(_l.recordingTranscript));
    await t.pumpAndSettle();
    expect(find.text('Priya: Let’s lock the API version today.'), findsOne);
    await t.tap(find.byKey(const ValueKey('recording-open-transcript')));
    expect(nav.opened.single, (id: 'rec-a', atMs: null));
  });

  testWidgets('[APP-02] the transcript opened at a time highlights that '
      'line', (t) async {
    await _pump(t, '/library/recordings/rec-a/text?t=13000');
    final tiles = t.widgetList<TranscriptLineTile>(
      find.byType(TranscriptLineTile),
    );
    expect([for (final l in tiles) l.highlighted], [false, true, false]);
  });

  testWidgets('[APP-02] cross-recording action items: open filter, recording '
      'link', (t) async {
    final c = await _pump(
      t,
      '/library/action-items',
      actionItems: const [
        ActionItemView(
          id: 1,
          recordingId: 'rec-a',
          recordingTitle: 'Weekly planning',
          body: 'Update the client SDK',
          done: false,
          owner: 'Sam',
          due: '2026-10-16',
        ),
      ],
    );
    expect(find.text('Update the client SDK'), findsOneWidget);
    expect(find.text('Sam · 2026-10-16 · Weekly planning'), findsOneWidget);
    await t.tap(find.byTooltip(_l.actionItemOpenRecording));
    await t.pumpAndSettle();
    expect(_path(c), '/library/recordings/rec-a');
  });

  testWidgets('[UIX-01/AC2] the detail is a hub: Summary, Transcript and '
      'Action items; no Mind map / Ask placeholder or PRO badge', (t) async {
    await _pump(t, '/library/recordings/rec-a');
    final tabs = find.byKey(const ValueKey('recording-tabs'));
    for (final label in [
      _l.recordingTabSummary,
      _l.recordingTranscript,
      _l.recordingTabActionItems,
    ]) {
      expect(
        find.descendant(of: tabs, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(t.widget<TabBar>(tabs).tabs, hasLength(3));
    expect(find.textContaining('PRO'), findsNothing);
    expect(find.textContaining('Mind map'), findsNothing);
    expect(find.textContaining('Ask'), findsNothing);
  });

  testWidgets('[UIX-01/AC2] a registered hub slot appears as a tab', (t) async {
    await _pump(
      t,
      '/library/recordings/rec-a',
      extra: [
        recordingHubSlotsProvider.overrideWithValue([
          RecordingHubSlot(
            id: 'test-slot',
            label: (_) => 'Slot label',
            builder: (_, id) => Text('slot for $id'),
          ),
        ]),
      ],
    );
    expect(find.text('Slot label'), findsOneWidget);
    await t.tap(find.text('Slot label'));
    await t.pumpAndSettle();
    expect(find.text('slot for rec-a'), findsOneWidget);
  });

  testWidgets('[UIX-01/AC2] the library groups date-sorted rows into one '
      'rounded card per day group', (t) async {
    await _pump(t, '/library');
    expect(find.byType(GroupedCard), findsWidgets);
    expect(find.byKey(const ValueKey('library-group-earlier')), findsOne);
  });

  test('[UIX-01/AC2] groupLibraryItems buckets by age and keeps order', () {
    final now = DateTime(2026, 10, 16, 12);
    LibraryItem at(String id, DateTime d) => LibraryItem(
      id: id,
      title: id,
      createdAt: d,
      duration: Duration.zero,
      status: LibraryStatus.exported,
    );
    final groups = groupLibraryItems([
      at('a', DateTime(2026, 10, 16, 9)),
      at('b', DateTime(2026, 10, 15, 23)),
      at('c', DateTime(2026, 10, 12)),
      at('d', DateTime(2026, 9)),
    ], now);
    expect(groups.map((g) => g.group), [
      LibraryGroup.today,
      LibraryGroup.yesterday,
      LibraryGroup.thisWeek,
      LibraryGroup.earlier,
    ]);
    expect(groupLibraryItems(const [], now), isEmpty);
  });
}
