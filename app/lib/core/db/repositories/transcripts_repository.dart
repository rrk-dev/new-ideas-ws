import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/transcript_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'transcripts_repository.g.dart';

/// Transcripts and their timed segments.
@DriftAccessor(tables: [Transcripts, TranscriptSegments])
class TranscriptsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$TranscriptsRepositoryMixin {
  TranscriptsRepository(super.attachedDatabase);

  Future<Result<void>> create(TranscriptsCompanion transcript) =>
      guardDb(() => into(transcripts).insert(transcript));

  Future<Result<TranscriptRow>> get(String id) => guardRow(
    () =>
        (select(transcripts)..where((t) => t.id.equals(id))).getSingleOrNull(),
  );

  /// Newest transcript of a recording, if any.
  Future<Result<TranscriptRow?>> latestFor(String recordingId) =>
      guardDb(() => _forRecording(recordingId).getSingleOrNull());

  Stream<TranscriptRow?> watchLatestFor(String recordingId) =>
      _forRecording(recordingId).watchSingleOrNull();

  SimpleSelectStatement<$TranscriptsTable, TranscriptRow> _forRecording(
    String recordingId,
  ) => select(transcripts)
    ..where((t) => t.recordingId.equals(recordingId))
    ..orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.desc(t.id),
    ])
    ..limit(1);

  Future<Result<void>> deleteById(String id) => guardAffected(
    () => (delete(transcripts)..where((t) => t.id.equals(id))).go(),
  );

  /// Inserts or overwrites segments by `(transcriptId, seq)`, so re-running an
  /// STT chunk after a resume never duplicates segments.
  Future<Result<void>> upsertSegments(
    List<TranscriptSegmentsCompanion> segments,
  ) => guardDb(
    () => batch((b) {
      for (final s in segments) {
        b.insert(
          transcriptSegments,
          s,
          onConflict: DoUpdate(
            (_) => s,
            target: [transcriptSegments.transcriptId, transcriptSegments.seq],
          ),
        );
      }
    }),
  );

  Stream<List<TranscriptSegmentRow>> watchSegments(String transcriptId) =>
      _segments(transcriptId).watch();

  Future<Result<List<TranscriptSegmentRow>>> segments(String transcriptId) =>
      guardDb(() => _segments(transcriptId).get());

  SimpleSelectStatement<$TranscriptSegmentsTable, TranscriptSegmentRow>
  _segments(String transcriptId) => select(transcriptSegments)
    ..where((s) => s.transcriptId.equals(transcriptId))
    ..orderBy([(s) => OrderingTerm.asc(s.seq)]);

  /// User edit of a segment: keeps the first pre-edit text in `originalText`
  /// and flags the transcript as edited.
  Future<Result<void>> editSegment(int segmentId, String newText) => guardDb(
    () => transaction(() async {
      final row = await (select(
        transcriptSegments,
      )..where((s) => s.id.equals(segmentId))).getSingle();
      await (update(
        transcriptSegments,
      )..where((s) => s.id.equals(segmentId))).write(
        TranscriptSegmentsCompanion(
          body: Value(newText),
          originalText: Value(row.originalText ?? row.body),
        ),
      );
      await (update(transcripts)..where((t) => t.id.equals(row.transcriptId)))
          .write(const TranscriptsCompanion(edited: Value(true)));
    }),
  );
}
