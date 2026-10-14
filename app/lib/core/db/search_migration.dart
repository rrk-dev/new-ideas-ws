import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.steps.dart';

/// v1 → v2 (APP-02): creates the FTS5 `search_index` and its sync triggers
/// from the frozen v2 snapshot (`database.steps.dart`), then backfills the
/// index from rows that already exist. Shipped steps are never edited.
Future<void> migrateToV2SearchIndex(Migrator m, GeneratedDatabase db) async {
  final schema = Schema2(database: db);
  final migrator = Migrator(db, schema);
  await migrator.create(schema.searchIndex);
  for (final trigger in [
    schema.searchRecordingInsert,
    schema.searchRecordingUpdate,
    schema.searchRecordingDelete,
    schema.searchSegmentInsert,
    schema.searchSegmentUpdate,
    schema.searchSegmentDelete,
    schema.searchTranscriptDelete,
    schema.searchExtractionInsert,
    schema.searchExtractionUpdate,
    schema.searchExtractionDelete,
  ]) {
    await migrator.create(trigger);
  }
  await backfillSearchIndex(db);
}

/// Rebuilds every row of `search_index` from recordings, transcripts and the
/// newest extraction of each recording (same content the triggers write).
Future<void> backfillSearchIndex(GeneratedDatabase db) async {
  await db.customStatement('DELETE FROM search_index');
  await db.customStatement(
    'INSERT INTO search_index (recording_id, kind, body) '
    "SELECT r.id, 'title', r.title || ' ' || COALESCE("
    "(SELECT group_concat(value, ' ') FROM json_each(r.tags)), '') "
    'FROM recordings r',
  );
  await db.customStatement(
    'INSERT INTO search_index (recording_id, kind, body) '
    "SELECT t.recording_id, 'transcript', group_concat(s.body, ' ') "
    'FROM transcripts t JOIN transcript_segments s '
    'ON s.transcript_id = t.id GROUP BY t.recording_id',
  );
  await db.customStatement(
    'INSERT INTO search_index (recording_id, kind, body) '
    "SELECT e.recording_id, 'extraction', group_concat(j.value, ' ') "
    'FROM extractions e, json_tree(e.json) j '
    'WHERE e.id = (SELECT e2.id FROM extractions e2 '
    'WHERE e2.recording_id = e.recording_id '
    'ORDER BY e2.created_at DESC, e2.id DESC LIMIT 1) '
    "AND j.type = 'text' GROUP BY e.id",
  );
}
