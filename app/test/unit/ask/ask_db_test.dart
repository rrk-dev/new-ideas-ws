import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/ask/data/db_ask_history.dart';
import 'package:vaultvoice/features/ask/data/db_ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';

Future<void> seed(
  VaultVoiceDatabase db,
  String id,
  List<String> lines, {
  DateTime? at,
}) async {
  await seedRecording(db, id, createdAt: at);
  await db
      .into(db.transcripts)
      .insert(
        TranscriptsCompanion.insert(
          id: 't-$id',
          recordingId: id,
          modelId: 'm',
          language: 'en',
          createdAt: at ?? t0,
        ),
      );
  for (final (i, line) in lines.indexed) {
    await db
        .into(db.transcriptSegments)
        .insert(
          TranscriptSegmentsCompanion.insert(
            transcriptId: 't-$id',
            seq: i,
            startMs: i * 4000,
            endMs: i * 4000 + 3000,
            body: line,
          ),
        );
  }
}

AskQuery q(String text, {String? recordingId, DateTime? now}) => AskQuery.parse(
  AskRequest(question: text, recordingId: recordingId),
  now ?? DateTime(2026, 3, 30),
);

void main() {
  late VaultVoiceDatabase db;
  late DbAskRetriever retriever;
  setUp(() {
    db = memoryDb();
    retriever = DbAskRetriever(db);
  });

  test('retrieval returns BM25 hits with their neighbour segments', () async {
    await seed(db, 'r1', [
      'Opening remarks',
      'The beta ships on the 9th',
      'Closing words',
    ]);
    final out = expectOk(
      await retriever.retrieve(q('When does the beta ship?')),
    );
    expect(out.first.text, contains('beta ships'));
    expect(out.first.timestamp, '00:00:04');
    expect(
      out.map((e) => e.text),
      containsAll(['Opening remarks', 'Closing words']),
    );
  });

  test("[ASK-03/AC6] [ASK-03/AC7] a per-recording Ask never returns another recording's "
      'passage', () async {
    await seed(db, 'r1', ['The budget is approved']);
    await seed(db, 'r2', ['The budget is rejected', 'budget budget budget']);
    final scoped = expectOk(
      await retriever.retrieve(q('What about the budget?', recordingId: 'r1')),
    );
    expect(scoped, isNotEmpty);
    expect(scoped.every((p) => p.recordingId == 'r1'), isTrue);
    final all = expectOk(await retriever.retrieve(q('What about the budget?')));
    expect({for (final p in all) p.recordingId}, {'r1', 'r2'});
  });

  test("a per-recording Ask always carries that recording's extraction, even "
      'when only its title matches', () async {
    await seed(db, 'r1', ['How are you?'], at: t0);
    await db
        .into(db.extractions)
        .insert(
          ExtractionsCompanion.insert(
            id: 'e1',
            recordingId: 'r1',
            profileId: 'meeting',
            profileVersion: 1,
            modelId: 'm',
            json: {
              'action_items': [
                {'text': 'Call the plumber'},
              ],
            },
            valid: true,
            createdAt: t0,
          ),
        );
    await db.customStatement("UPDATE recordings SET title = 'Debug2'");
    final out = expectOk(
      await retriever.retrieve(
        q('What is the action item in Debug2', recordingId: 'r1'),
      ),
    );
    expect(
      out.where((e) => e.kind == AskPassageKind.extraction).map((e) => e.text),
      [contains('Call the plumber')],
    );
  });

  test(
    "a date with no keyword hit falls back to that day's recordings",
    () async {
      await seed(db, 'a', [
        'Laws of motion today',
      ], at: DateTime(2026, 3, 27, 12));
      await seed(db, 'b', ['Other things'], at: DateTime(2026, 3, 26, 12));
      final out = expectOk(
        await retriever.retrieve(q('What did the lecture on Friday cover?')),
      );
      expect(out.map((e) => e.recordingId).toSet(), {'a'});
    },
  );

  test('date filter keeps only recordings of that day', () async {
    await seed(db, 'old', ['warranty note'], at: DateTime(2026, 3, 1, 12));
    await seed(db, 'new', ['warranty note'], at: DateTime(2026, 3, 29, 12));
    final out = expectOk(
      await retriever.retrieve(q('warranty from yesterday?')),
    );
    expect({for (final p in out) p.recordingId}, {'new'});
  });

  test('a date-only question lists the recordings of the range', () async {
    await seed(db, 'a', ['hello'], at: DateTime(2026, 3, 29, 9));
    await seed(db, 'b', ['hello'], at: DateTime(2026, 3, 10, 9));
    final out = expectOk(
      await retriever.retrieve(q('What did I record yesterday?')),
    );
    expect(out.map((e) => e.recordingId), ['a']);
  });

  group('history', () {
    late FakeClock clock;
    late DbAskHistory history;
    setUp(() {
      clock = FakeClock(DateTime.utc(2026, 3));
      history = DbAskHistory(db, clock: clock);
    });

    test('[ASK-03/AC4] deleting a recording removes it from retrieval and '
        'from stored chat citations', () async {
      await seed(db, 'ra', ['solar panels cost money']);
      await seed(db, 'rb', ['solar panels save money']);
      final saved = expectOk(
        await history.saveTurn(
          question: 'solar?',
          answer: 'both',
          found: true,
          citations: const [
            Citation(recordingId: 'ra', tMs: 0),
            Citation(recordingId: 'rb', tMs: 0),
          ],
        ),
      );
      expect(expectOk(await history.threads()), hasLength(1));

      await db.recordingsRepository.deleteById('ra');

      final hits = expectOk(await retriever.retrieve(q('solar panels')));
      expect(hits.map((e) => e.recordingId), isNot(contains('ra')));
      expect(expectOk(await history.threads()), isEmpty);
      expect(
        await db.select(db.askCitations).get(),
        isEmpty,
        reason: 'turn ${saved.turnId} and all its citations are gone',
      );
    });

    test('[ASK-03/AC6] [ASK-03/AC8] transcript expiry with audio kept removes stored '
        'answers, citations and per-recording threads', () async {
      final tmp = Directory.systemTemp.createTempSync('vv_ask_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      await seed(db, 'ra', ['solar panels cost money']);
      await seed(db, 'rb', ['wind turbines']);
      expectOk(
        await history.saveTurn(
          question: 'solar?',
          answer: 'costly',
          found: true,
          citations: const [Citation(recordingId: 'ra', tMs: 0)],
        ),
      );
      expectOk(
        await history.saveTurn(
          question: 'wind?',
          answer: 'turbines',
          found: true,
          citations: const [Citation(recordingId: 'rb', tMs: 0)],
        ),
      );
      expectOk(
        await history.saveTurn(
          recordingId: 'ra',
          question: 'anything?',
          answer: kAskNotFoundText,
          found: false,
          citations: const [],
        ),
      );

      expectOk(
        await RecordingPurger(
          db,
          StoragePaths(p.join(tmp.path, 'vv')),
        ).purge('ra', scope: PurgeScope.transcripts),
      );

      final threads = expectOk(await history.threads());
      expect(threads, hasLength(1));
      expect(threads.single.turns.single.question, 'wind?');
      expect(
        (await db.select(db.askCitations).get()).map((c) => c.recordingId),
        ['rb'],
      );
      expect(await db.select(db.recordings).get(), hasLength(2));
    });

    test('save, delete one, clear all and 30-day expiry', () async {
      await seed(db, 'ra', ['x y z']);
      Future<String> save(String q) async => expectOk(
        await history.saveTurn(
          question: q,
          answer: 'a',
          found: true,
          citations: const [Citation(recordingId: 'ra', tMs: 0)],
        ),
      ).threadId;
      final old = await save('old');
      clock.advance(const Duration(days: 31));
      final fresh = await save('fresh');
      final second = expectOk(
        await history.saveTurn(
          threadId: fresh,
          question: 'follow up',
          answer: 'b',
          found: false,
          citations: const [],
        ),
      );
      expect(second.threadId, fresh);

      expect(
        expectOk(
          await history.deleteOlderThan(
            clock.now().subtract(const Duration(days: 30)),
          ),
        ),
        1,
      );
      expect(expectOk(await history.threads()).map((t) => t.id), [fresh]);
      expect(expectOk(await history.threads()).single.turns, hasLength(2));
      expect(old, isNot(fresh));

      expectOk(await history.deleteThread(fresh));
      expect(expectOk(await history.threads()), isEmpty);
      await save('again');
      expectOk(await history.clearAll());
      expect(await db.select(db.askThreads).get(), isEmpty);
      expect(await db.select(db.askTurns).get(), isEmpty);
      expect(await db.select(db.askCitations).get(), isEmpty);
    });
  });
}
