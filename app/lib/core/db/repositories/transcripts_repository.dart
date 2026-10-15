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
  Future<Result<void>> editSegment(int segmentId, String newText) =>
      guardDb(() => transaction(() => _edit(segmentId, newText)));

  /// Several edits of one transcript in one transaction (STT-06 find &
  /// replace). Every segment must belong to [transcriptId]; otherwise
  /// nothing is written (replace is scoped to one transcript).
  Future<Result<void>> editSegments(
    String transcriptId,
    Map<int, String> edits,
  ) => guardDb(
    () => transaction(() async {
      for (final MapEntry(key: id, value: text) in edits.entries) {
        final owner = await _edit(id, text);
        if (owner != transcriptId) {
          throw StateError('segment outside the transcript');
        }
      }
    }),
  );

  /// Writes diarization output (STT-05) in one transaction: every segment
  /// gets its speaker label; a segment cut at a speaker change keeps its row
  /// for the first part and gains rows for the others. Sequence numbers are
  /// renumbered per audio chunk (`seq ~/ 100000`) so order and the
  /// `chunk * 100000 + index` convention survive. Unsplit segments keep their
  /// text (user edits stay). Pieces of one source must be consecutive.
  Future<Result<void>> applyDiarization(
    String transcriptId,
    List<
      ({
        int sourceId,
        int startMs,
        int endMs,
        String body,
        String? tokensJson,
        String? speaker,
        bool isSplit,
      })
    >
    pieces,
  ) => guardDb(
    () => transaction(() async {
      final rows = await _segments(transcriptId).get();
      for (final r in rows) {
        await (update(transcriptSegments)..where((s) => s.id.equals(r.id)))
            .write(TranscriptSegmentsCompanion(seq: Value(-r.id)));
      }
      final bySource =
          <
            int,
            List<
              ({
                int sourceId,
                int startMs,
                int endMs,
                String body,
                String? tokensJson,
                String? speaker,
                bool isSplit,
              })
            >
          >{};
      for (final p in pieces) {
        bySource.putIfAbsent(p.sourceId, () => []).add(p);
      }
      final next = <int, int>{};
      for (final r in rows) {
        final chunk = r.seq ~/ 100000;
        final mine = bySource[r.id];
        if (mine == null || mine.isEmpty) {
          final idx = next[chunk] = (next[chunk] ?? -1) + 1;
          await (update(
            transcriptSegments,
          )..where((s) => s.id.equals(r.id))).write(
            TranscriptSegmentsCompanion(seq: Value(chunk * 100000 + idx)),
          );
          continue;
        }
        for (final (i, p) in mine.indexed) {
          final idx = next[chunk] = (next[chunk] ?? -1) + 1;
          final seq = chunk * 100000 + idx;
          if (i == 0) {
            await (update(
              transcriptSegments,
            )..where((s) => s.id.equals(r.id))).write(
              TranscriptSegmentsCompanion(
                seq: Value(seq),
                speaker: Value(p.speaker),
                startMs: p.isSplit ? Value(p.startMs) : const Value.absent(),
                endMs: p.isSplit ? Value(p.endMs) : const Value.absent(),
                body: p.isSplit ? Value(p.body) : const Value.absent(),
                tokensJson: p.isSplit
                    ? Value(p.tokensJson)
                    : const Value.absent(),
              ),
            );
          } else {
            await into(transcriptSegments).insert(
              TranscriptSegmentsCompanion.insert(
                transcriptId: transcriptId,
                seq: seq,
                startMs: p.startMs,
                endMs: p.endMs,
                body: p.body,
                speaker: Value(p.speaker),
                avgLogprob: Value(r.avgLogprob),
                tokensJson: Value(p.tokensJson),
              ),
            );
          }
        }
      }
    }),
  );

  Future<String> _edit(int segmentId, String newText) async {
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
    return row.transcriptId;
  }
}
