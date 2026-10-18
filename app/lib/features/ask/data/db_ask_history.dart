import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';

/// [AskHistoryStore] over the `ask_*` tables (schema v3).
final class DbAskHistory implements AskHistoryStore {
  DbAskHistory(this.db, {this.clock = const SystemClock(), IdGenerator? ids})
    : _ids = ids ?? RandomIdGenerator();

  final VaultVoiceDatabase db;
  final Clock clock;
  final IdGenerator _ids;

  @override
  Future<Result<({String threadId, String turnId})>> saveTurn({
    required String question,
    required String answer,
    required bool found,
    required List<Citation> citations,
    String? threadId,
    String? recordingId,
  }) => guardDb(
    () => db.transaction(() async {
      final now = clock.now();
      var thread = threadId;
      if (thread == null) {
        thread = _ids.next();
        await db
            .into(db.askThreads)
            .insert(
              AskThreadsCompanion.insert(
                id: thread,
                recordingId: Value(recordingId),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (db.update(db.askThreads)..where((t) => t.id.equals(thread!)))
            .write(AskThreadsCompanion(updatedAt: Value(now)));
      }
      final seq =
          await (db.selectOnly(db.askTurns)
                ..addColumns([db.askTurns.seq.max()])
                ..where(db.askTurns.threadId.equals(thread)))
              .map((r) => r.read(db.askTurns.seq.max()))
              .getSingle();
      final turnId = _ids.next();
      await db
          .into(db.askTurns)
          .insert(
            AskTurnsCompanion.insert(
              id: turnId,
              threadId: thread,
              seq: (seq ?? -1) + 1,
              question: question,
              answer: answer,
              found: found,
              createdAt: now,
            ),
          );
      for (final c in citations) {
        await db
            .into(db.askCitations)
            .insert(
              AskCitationsCompanion.insert(
                turnId: turnId,
                recordingId: c.recordingId,
                tMs: c.tMs,
              ),
            );
      }
      return (threadId: thread, turnId: turnId);
    }),
  );

  @override
  Future<Result<List<AskThread>>> threads() => guardDb(() async {
    final threads = await (db.select(
      db.askThreads,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    final out = <AskThread>[];
    for (final t in threads) {
      final turns =
          await (db.select(db.askTurns)
                ..where((u) => u.threadId.equals(t.id))
                ..orderBy([(u) => OrderingTerm.asc(u.seq)]))
              .get();
      final turnList = <AskTurn>[];
      for (final u in turns) {
        final cites = await (db.select(
          db.askCitations,
        )..where((c) => c.turnId.equals(u.id))).get();
        turnList.add(
          AskTurn(
            id: u.id,
            question: u.question,
            answer: u.answer,
            found: u.found,
            citations: [
              for (final c in cites)
                Citation(recordingId: c.recordingId, tMs: c.tMs),
            ],
            createdAt: u.createdAt,
          ),
        );
      }
      out.add(
        AskThread(
          id: t.id,
          recordingId: t.recordingId,
          updatedAt: t.updatedAt,
          turns: turnList,
        ),
      );
    }
    return out;
  });

  @override
  Future<Result<void>> deleteThread(String threadId) => guardDb(
    () => (db.delete(db.askThreads)..where((t) => t.id.equals(threadId))).go(),
  );

  @override
  Future<Result<void>> clearAll() =>
      guardDb(() => db.delete(db.askThreads).go());

  @override
  Future<Result<int>> deleteOlderThan(DateTime cutoff) => guardDb(
    () =>
        (db.delete(db.askThreads)..where(
              (t) =>
                  t.updatedAt.isSmallerThanValue(cutoff.millisecondsSinceEpoch),
            ))
            .go(),
  );
}
