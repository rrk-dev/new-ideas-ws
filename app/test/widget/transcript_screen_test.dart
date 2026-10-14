import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_providers.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_screen.dart';

import '../db/db_test_utils.dart' show expectOk, seedRecording, t0;
import '../fakes/fake_transcript_player.dart';

final AppLocalizations en = lookupAppLocalizations(kFallbackLocale);

/// Seeds recording `r1` with a 3-segment transcript and markers.
/// In-memory DB *without* a tearDown close: widget tests run in a fake
/// zone, so the DB is closed by [_finish] via `runAsync`.
VaultVoiceDatabase _db() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return VaultVoiceDatabase(NativeDatabase.memory());
}

/// Unmounts the tree (cancels drift stream timers) and closes [db].
Future<void> _finish(WidgetTester t, VaultVoiceDatabase db) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
  await t.runAsync(db.close);
}

Future<VaultVoiceDatabase> _seed() async {
  final db = _db();
  await seedRecording(db, 'r1');
  expectOk(
    await db.transcriptsRepository.create(
      TranscriptsCompanion.insert(
        id: 't1',
        recordingId: 'r1',
        modelId: 'whisper-base.en-q5_1',
        language: 'en',
        createdAt: t0,
      ),
    ),
  );
  final tokens = jsonEncode([
    {'text': ' Ask', 'p': 0.9},
    {'text': ' Jon', 'p': 0.2},
    {'text': ' today', 'p': 0.95},
  ]);
  expectOk(
    await db.transcriptsRepository.upsertSegments([
      TranscriptSegmentsCompanion.insert(
        transcriptId: 't1',
        seq: 0,
        startMs: 0,
        endMs: 4000,
        body: 'Ask Jon today',
        speaker: const Value('Speaker 1'),
        tokensJson: Value(tokens),
      ),
      TranscriptSegmentsCompanion.insert(
        transcriptId: 't1',
        seq: 1,
        startMs: 5000,
        endMs: 9000,
        body: 'Jon will send the notes',
      ),
      TranscriptSegmentsCompanion.insert(
        transcriptId: 't1',
        seq: 2,
        startMs: 65000,
        endMs: 70000,
        body: 'Budget review next week',
      ),
    ]),
  );
  expectOk(
    await db.recordingsRepository.addMarker(
      MarkersCompanion.insert(
        recordingId: 'r1',
        atMs: 6000,
        kind: MarkerKind.user,
        label: const Value('Decision'),
      ),
    ),
  );
  return db;
}

PlaybackTimeline _timeline() => PlaybackTimeline(const [
  PlaybackChunk(path: '/c0', startMs: 0, pcmBytes: 30000 * 32),
  PlaybackChunk(path: '/c1', startMs: 60000, pcmBytes: 30000 * 32),
]);

List<Override> _overrides(VaultVoiceDatabase db, FakeTranscriptPlayer player) =>
    [
      vaultVoiceDatabaseProvider.overrideWithValue(db),
      transcriptPlaybackProvider('r1').overrideWith((ref) async {
        final p = TranscriptPlayback(player, _timeline());
        return p;
      }),
    ];

Future<void> _pump(WidgetTester t, List<Override> overrides) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: TranscriptScreen(recordingId: 'r1')),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('[STT-06/AC1] user markers appear between the segments at '
      'their positions; speaker chips, timestamps, low-confidence words', (
    t,
  ) async {
    final db = (await t.runAsync(_seed))!;
    await _pump(t, _overrides(db, FakeTranscriptPlayer()));

    final s0 = t.getTopLeft(find.text('Ask Jon today', findRichText: true));
    final s1 = t.getTopLeft(find.text('Jon will send the notes'));
    final marker = t.getTopLeft(find.text('Decision'));
    final s2 = t.getTopLeft(find.text('Budget review next week'));
    // Marker at 0:06 is inside segment 2 (0:05–0:09) → right after it.
    expect(s0.dy, lessThan(s1.dy));
    expect(s1.dy, lessThan(marker.dy));
    expect(marker.dy, lessThan(s2.dy));
    expect(find.text('0:06'), findsOneWidget); // marker time
    expect(find.text('1:05'), findsOneWidget); // segment time
    expect(find.text('Speaker 1'), findsOneWidget);
    expect(find.text(en.transcriptLowConfidenceHint), findsOneWidget);

    // "Jon" (p = 0.2) is underlined wavy in the first segment.
    final rich = t.widget<RichText>(
      find
          .descendant(
            of: find.byKey(const ValueKey('segment-1')),
            matching: find.byType(RichText),
          )
          .last,
    );
    final spans = <TextSpan>[];
    (rich.text as TextSpan).visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    final jon = spans.singleWhere((s) => s.text == 'Jon');
    expect(jon.style?.decoration, TextDecoration.underline);
    expect(jon.style?.decorationStyle, TextDecorationStyle.wavy);
    await _finish(t, db);
  });

  testWidgets('tap on a segment plays from its start; the playing segment '
      'is highlighted', (t) async {
    final db = (await t.runAsync(_seed))!;
    final player = FakeTranscriptPlayer();
    await _pump(t, _overrides(db, player));

    await t.tap(find.text('Budget review next week'));
    await t.pumpAndSettle();
    // 65 s recording time = 35 s into the stream (chunk 2 starts at 30 s).
    expect(player.seeks.last, const Duration(seconds: 35));
    expect(player.isPlaying, isTrue);

    player.emitPosition(const Duration(seconds: 6));
    await t.pumpAndSettle();
    Color? bg(int id) => t
        .widget<Container>(
          find
              .descendant(
                of: find.byKey(ValueKey('segment-$id')),
                matching: find.byType(Container),
              )
              .first,
        )
        .color;
    final scheme = Theme.of(t.element(find.byType(Scaffold))).colorScheme;
    expect(bg(2), scheme.secondaryContainer);
    expect(bg(1), isNull);
    expect(find.byTooltip(en.transcriptPause), findsOneWidget);
    await _finish(t, db);
  });

  testWidgets('inline edit persists and keeps the original text', (t) async {
    final db = (await t.runAsync(_seed))!;
    await _pump(t, _overrides(db, FakeTranscriptPlayer()));

    await t.tap(find.byTooltip(en.transcriptEditSegment('0:05')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'John will send the notes');
    await t.tap(find.text(en.commonSave));
    await t.pumpAndSettle();

    expect(find.text('John will send the notes'), findsOneWidget);
    expect(find.text(en.transcriptEdited), findsOneWidget);
    final rows = expectOk(
      (await t.runAsync(() => db.transcriptsRepository.segments('t1')))!,
    );
    expect(rows[1].body, 'John will send the notes');
    expect(rows[1].originalText, 'Jon will send the notes');
    await _finish(t, db);
  });

  testWidgets('find & replace fixes a misheard name everywhere', (t) async {
    final db = (await t.runAsync(_seed))!;
    await _pump(t, _overrides(db, FakeTranscriptPlayer()));

    await t.tap(find.byTooltip(en.transcriptFindReplace));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, en.transcriptFind), 'jon');
    await t.pump();
    expect(find.text(en.transcriptMatchCount(2)), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextField, en.transcriptReplaceWith),
      'John',
    );
    await t.tap(find.text(en.transcriptReplaceAll));
    await t.pumpAndSettle();

    expect(find.text(en.transcriptReplaced(2)), findsOneWidget);
    expect(find.text('Ask John today', findRichText: true), findsOneWidget);
    expect(find.text('John will send the notes'), findsOneWidget);
    await _finish(t, db);
  });

  testWidgets('re-extract reports a failure when there is no job', (t) async {
    final db = (await t.runAsync(_seed))!;
    await _pump(t, _overrides(db, FakeTranscriptPlayer()));
    await t.tap(find.byTooltip(en.transcriptReExtract));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    expect(find.text(en.transcriptReExtractFailed), findsOneWidget);
    await _finish(t, db);
  });

  testWidgets('empty, error and loading states', (t) async {
    final db = _db();
    await t.runAsync(() => seedRecording(db, 'r1'));
    await _pump(t, _overrides(db, FakeTranscriptPlayer()));
    expect(find.text(en.transcriptEmpty), findsOneWidget);
    await _finish(t, db);

    await t.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          transcriptViewProvider('r1')
              .overrideWith((ref) => Future.error(StateError('x'))),
        ],
        child: const MaterialApp(home: TranscriptScreen(recordingId: 'r1')),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(en.transcriptLoadFailed), findsOneWidget);
    expect(find.text(en.commonTryAgain), findsOneWidget);

    final never = Completer<TranscriptViewData?>();
    await t.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          transcriptViewProvider('r1').overrideWith((ref) => never.future),
        ],
        child: const MaterialApp(home: TranscriptScreen(recordingId: 'r1')),
      ),
    );
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('without audio the player bar says playback is unavailable', (
    t,
  ) async {
    final db = (await t.runAsync(_seed))!;
    await _pump(t, [
      vaultVoiceDatabaseProvider.overrideWithValue(db),
      transcriptPlaybackProvider('r1').overrideWith(
        (ref) => Future<TranscriptPlayback>.error(StateError('no chunks')),
      ),
    ]);
    expect(find.text(en.transcriptPlaybackUnavailable), findsOneWidget);
    await t.tap(find.text('Budget review next week'));
    await t.pumpAndSettle();
    await _finish(t, db);
  });
}
