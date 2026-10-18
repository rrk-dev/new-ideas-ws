import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/ask/domain/ask_availability.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/presentation/ask_history_screen.dart';
import 'package:vaultvoice/features/ask/presentation/ask_panel.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/presentation/recording_detail_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

import '../fakes/fake_ask_engine.dart';

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

class _Nav implements TranscriptNavigator {
  final opened = <({String id, int? atMs})>[];

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      opened.add((id: recordingId, atMs: atMs));
}

class _Lock extends AppLock {
  @override
  AppLockView build() => const AppLockView(enabled: true, locked: false);

  void lock() => state = const AppLockView(enabled: true, locked: true);
}

class _History implements AskHistoryStore {
  _History(this.items);

  List<AskThread> items;

  @override
  Future<Result<List<AskThread>>> threads() async => Ok(items);

  @override
  Future<Result<void>> deleteThread(String threadId) async {
    items = [
      for (final t in items)
        if (t.id != threadId) t,
    ];
    return const Ok(null);
  }

  @override
  Future<Result<void>> clearAll() async {
    items = [];
    return const Ok(null);
  }

  @override
  Future<Result<int>> deleteOlderThan(DateTime cutoff) async => const Ok(0);

  @override
  Future<Result<({String threadId, String turnId})>> saveTurn({
    required String question,
    required String answer,
    required bool found,
    required List<Citation> citations,
    String? threadId,
    String? recordingId,
  }) async => const Ok((threadId: 't', turnId: 'u'));
}

const _answer = AskAnswer(
  outcome: AskOutcome.answered,
  answer: 'The launch moved to May.',
  citations: [Citation(recordingId: 'rec-a', tMs: 83000)],
  threadId: 'th1',
);

Future<_Nav> _pump(
  WidgetTester t, {
  FakeAskEngine? engine,
  AskAvailability availability = AskAvailability.ready,
  Widget home = const AskPanel(),
  List<Override> extra = const [],
  _Lock? lock,
  bool recordings = true,
}) async {
  t.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final nav = _Nav();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        askEngineProvider.overrideWith(
          (ref) async => engine ?? FakeAskEngine(answer: _answer),
        ),
        askAvailabilityStateProvider.overrideWith((ref) async => availability),
        askModelEntryProvider.overrideWith((ref) async => null),
        libraryItemsProvider.overrideWith(
          (ref) => Stream.value(recordings ? [_item()] : const []),
        ),
        processingViewsProvider.overrideWith((ref) async => const []),
        recordingHeaderProvider('rec-a')
            .overrideWith((ref) => Stream.value(null)),
        askSaveHistoryEnabledProvider.overrideWithValue(true),
        askEnabledProvider.overrideWithValue(true),
        transcriptNavigatorProvider.overrideWithValue(nav),
        appLockProvider.overrideWith(() => lock ?? _Lock()),
        ...extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(body: home),
      ),
    ),
  );
  await t.pumpAndSettle();
  return nav;
}

Future<void> _ask(WidgetTester t, String q) async {
  await t.enterText(find.byKey(const ValueKey('ask-input')), q);
  await t.tap(find.byKey(const ValueKey('ask-send')));
  await t.pumpAndSettle();
}

class _Hanging extends FakeAskEngine {
  final gate = Completer<void>();

  @override
  Future<Result<AskAnswer>> ask(
    AskRequest request, {
    CancelToken? cancel,
  }) async {
    await gate.future;
    return const Err(CancelledFailure());
  }
}

void main() {
  testWidgets('[ASK-04/AC1] ready: answer with citation chip and the '
      '"can be wrong" note', (t) async {
    final engine = FakeAskEngine(answer: _answer);
    await _pump(t, engine: engine);
    await _ask(t, 'When is the launch?');
    expect(find.text('The launch moved to May.'), findsOneWidget);
    expect(find.text(_l.aiOutputDisclaimer), findsOneWidget);
    expect(find.text('00:01:23'), findsOneWidget);
    expect(engine.requests.single.question, 'When is the launch?');
  });

  testWidgets('[ASK-04/AC1] refusal text and no citations', (t) async {
    await _pump(t, engine: FakeAskEngine());
    await _ask(t, 'What is the CEO salary?');
    expect(find.text("I couldn't find that in your notes."), findsOneWidget);
    expect(find.text(_l.askSourcesTitle), findsNothing);
  });

  testWidgets('[ASK-04/AC1] error offers retry', (t) async {
    final engine = FakeAskEngine(failure: const OutOfMemoryFailure());
    await _pump(t, engine: engine);
    await _ask(t, 'Anything?');
    expect(find.text(_l.askError), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ask-retry')));
    await t.pumpAndSettle();
    expect(engine.requests, hasLength(2));
  });

  testWidgets('[ASK-04/AC1] in progress shows Stop; cancelling ends it', (
    t,
  ) async {
    final engine = _Hanging();
    await _pump(t, engine: engine);
    await t.enterText(find.byKey(const ValueKey('ask-input')), 'Q?');
    await t.tap(find.byKey(const ValueKey('ask-send')));
    await t.pump();
    expect(find.text(_l.askWorking), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ask-cancel')));
    await t.pump();
    engine.gate.complete();
    await t.pumpAndSettle();
    expect(find.text(_l.askWorking), findsNothing);
  });

  testWidgets('[ASK-04/AC1] locked feature shows the paywall entry', (t) async {
    await _pump(
      t,
      extra: [featureProvider(Feature.askNotes).overrideWithValue(false)],
    );
    expect(find.text(_l.askLocked), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-input')), findsNothing);
  });

  testWidgets('[ASK-04/AC1] 3B missing: "Ask requires the 3B model" with '
      'Open Models', (t) async {
    await _pump(t, availability: AskAvailability.needsModel);
    expect(find.text('Ask requires the 3B model'), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-open-models')), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-input')), findsNothing);
  });

  testWidgets('[ASK-04/AC1] Mid/Low tier: not available', (t) async {
    await _pump(t, availability: AskAvailability.deviceTooLow);
    expect(find.text(_l.askUnavailableDevice), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-input')), findsNothing);
  });

  testWidgets('[ASK-04/AC1] empty library explains what to do first', (
    t,
  ) async {
    await _pump(t, recordings: false);
    expect(find.text(_l.askNoRecordings), findsOneWidget);
  });

  testWidgets('[ASK-04/AC1] app lock clears the conversation', (t) async {
    final lock = _Lock();
    await _pump(t, lock: lock);
    await _ask(t, 'When is the launch?');
    expect(find.text('The launch moved to May.'), findsOneWidget);
    lock.lock();
    await t.pumpAndSettle();
    expect(find.text('The launch moved to May.'), findsNothing);
    expect(find.text('When is the launch?'), findsNothing);
  });

  testWidgets('[ASK-04/AC2] tapping a citation opens the recording at its '
      'time', (t) async {
    final nav = await _pump(t);
    await _ask(t, 'When is the launch?');
    await t.tap(find.byType(ActionChip));
    await t.pumpAndSettle();
    expect(nav.opened.single, (id: 'rec-a', atMs: 83000));
  });

  testWidgets('[ASK-04/AC1] history: delete one and clear all', (t) async {
    final store = _History([
      _thread('a', 'First question'),
      _thread('b', 'Second question'),
    ]);
    await _pump(
      t,
      home: const AskHistoryScreen(),
      extra: [askHistoryStoreProvider.overrideWithValue(store)],
    );
    expect(find.text('First question'), findsOneWidget);
    expect(find.text(_l.askHistoryExpiryNote), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ask-delete-a')));
    await t.pumpAndSettle();
    expect(find.text('First question'), findsNothing);
    expect(find.text('Second question'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ask-clear-all')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('ask-clear-confirm')));
    await t.pumpAndSettle();
    expect(store.items, isEmpty);
    expect(find.text(_l.askHistoryEmpty), findsOneWidget);
  });

  test('[ASK-04/AC1] the Ask tab is hidden unless ask.enabled', () {
    final off = ProviderContainer(
      overrides: [askEnabledProvider.overrideWithValue(false)],
    );
    final on = ProviderContainer(
      overrides: [askEnabledProvider.overrideWithValue(true)],
    );
    addTearDown(off.dispose);
    addTearDown(on.dispose);
    expect(
      off.read(recordingHubSlotsProvider).map((s) => s.id),
      isNot(contains('ask')),
    );
    expect(
      on.read(recordingHubSlotsProvider).map((s) => s.id),
      contains('ask'),
    );
  });
}

AskThread _thread(String id, String question) => AskThread(
  id: id,
  recordingId: null,
  updatedAt: DateTime(2026, 10, 18),
  turns: [
    AskTurn(
      id: '$id-1',
      question: question,
      answer: 'x',
      found: true,
      citations: const [],
      createdAt: DateTime(2026, 10, 18),
    ),
  ],
);

LibraryItem _item() => LibraryItem(
  id: 'rec-a',
  title: 'Weekly planning',
  createdAt: DateTime(2026, 10, 12),
  duration: const Duration(minutes: 23),
  status: LibraryStatus.exported,
);
