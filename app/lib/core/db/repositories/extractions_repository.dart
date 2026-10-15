import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/extraction_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'extractions_repository.g.dart';

/// LLM extractions and the action items derived from them.
@DriftAccessor(tables: [Extractions, ActionItems])
class ExtractionsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$ExtractionsRepositoryMixin {
  ExtractionsRepository(super.attachedDatabase);

  /// Inserts or replaces the extraction with the same id (re-running a step
  /// with the same id overwrites).
  Future<Result<void>> upsert(ExtractionsCompanion extraction) =>
      guardDb(() => into(extractions).insertOnConflictUpdate(extraction));

  Future<Result<ExtractionRow>> get(String id) => guardRow(
    () =>
        (select(extractions)..where((e) => e.id.equals(id))).getSingleOrNull(),
  );

  /// Newest first.
  Stream<List<ExtractionRow>> watchForRecording(String recordingId) =>
      (select(extractions)
            ..where((e) => e.recordingId.equals(recordingId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.createdAt),
              (e) => OrderingTerm.desc(e.id),
            ]))
          .watch();

  Future<Result<void>> deleteById(String id) => guardAffected(
    () => (delete(extractions)..where((e) => e.id.equals(id))).go(),
  );

  /// Replaces the extracted JSON of [id] (APP-05 review edits).
  Future<Result<void>> updateJson(
    String id,
    Map<String, Object?> json, {
    required bool valid,
  }) => guardAffected(
    () => (update(extractions)..where((e) => e.id.equals(id))).write(
      ExtractionsCompanion(json: Value(json), valid: Value(valid)),
    ),
  );

  /// Replaces the action items of [extractionId] atomically (idempotent
  /// RenderStep output).
  Future<Result<void>> replaceActionItems(
    String extractionId,
    List<ActionItemsCompanion> items,
  ) => guardDb(
    () => transaction(() async {
      await (delete(
        actionItems,
      )..where((a) => a.extractionId.equals(extractionId))).go();
      await batch((b) => b.insertAll(actionItems, items));
    }),
  );

  /// Action items across recordings; [openOnly] hides finished ones.
  Stream<List<ActionItemRow>> watchActionItems({
    bool openOnly = false,
    String? recordingId,
  }) {
    final query = select(actionItems)..orderBy([(a) => OrderingTerm.asc(a.id)]);
    if (openOnly) query.where((a) => a.done.equals(false));
    if (recordingId != null) {
      query.where((a) => a.recordingId.equals(recordingId));
    }
    return query.watch();
  }

  /// Marks an action item done (with [at]) or open again.
  Future<Result<void>> setActionItemDone(
    int id, {
    required bool done,
    DateTime? at,
  }) => guardAffected(
    () => (update(actionItems)..where((a) => a.id.equals(id))).write(
      ActionItemsCompanion(done: Value(done), doneAt: Value(done ? at : null)),
    ),
  );
}
