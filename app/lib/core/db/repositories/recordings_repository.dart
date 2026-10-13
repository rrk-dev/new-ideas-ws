import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'recordings_repository.g.dart';

/// Recordings and their per-recording children (audio chunks, VAD segments,
/// markers, speakers).
@DriftAccessor(
  tables: [Recordings, AudioChunks, SpeechSegments, Markers, Speakers],
)
class RecordingsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$RecordingsRepositoryMixin {
  RecordingsRepository(super.attachedDatabase);

  Future<Result<void>> create(RecordingsCompanion recording) =>
      guardDb(() => into(recordings).insert(recording));

  Future<Result<RecordingRow>> get(String id) => guardRow(
    () => (select(recordings)..where((r) => r.id.equals(id))).getSingleOrNull(),
  );

  /// Newest first.
  Stream<List<RecordingRow>> watchAll() =>
      (select(recordings)..orderBy([
            (r) => OrderingTerm.desc(r.createdAt),
            (r) => OrderingTerm.asc(r.id),
          ]))
          .watch();

  Stream<RecordingRow?> watch(String id) =>
      (select(recordings)..where((r) => r.id.equals(id))).watchSingleOrNull();

  Future<Result<List<RecordingRow>>> findByStatus(RecordingStatus status) =>
      guardDb(
        () => (select(
          recordings,
        )..where((r) => r.status.equalsValue(status))).get(),
      );

  /// Applies the non-absent fields of [patch].
  Future<Result<void>> updateFields(String id, RecordingsCompanion patch) =>
      guardAffected(
        () => (update(recordings)..where((r) => r.id.equals(id))).write(patch),
      );

  /// Deletes the recording and (via cascading foreign keys) every child row,
  /// including transcripts, jobs, extractions and exports. Files on disk are
  /// removed by the secure-deletion path (SEC-04).
  Future<Result<void>> deleteById(String id) => guardAffected(
    () => (delete(recordings)..where((r) => r.id.equals(id))).go(),
  );

  /// Inserts or replaces the chunk with the same `(recordingId, seq)`.
  Future<Result<void>> upsertChunk(AudioChunksCompanion chunk) => guardDb(
    () => into(audioChunks).insert(
      chunk,
      onConflict: DoUpdate(
        (_) => chunk,
        target: [audioChunks.recordingId, audioChunks.seq],
      ),
    ),
  );

  Stream<List<AudioChunkRow>> watchChunks(String recordingId) =>
      (select(audioChunks)
            ..where((c) => c.recordingId.equals(recordingId))
            ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
          .watch();

  /// Replaces all VAD segments of a recording in one transaction.
  Future<Result<void>> replaceSpeechSegments(
    String recordingId,
    List<SpeechSegmentsCompanion> segments,
  ) => guardDb(
    () => transaction(() async {
      await (delete(
        speechSegments,
      )..where((s) => s.recordingId.equals(recordingId))).go();
      await batch((b) => b.insertAll(speechSegments, segments));
    }),
  );

  Stream<List<SpeechSegmentRow>> watchSpeechSegments(String recordingId) =>
      (select(speechSegments)
            ..where((s) => s.recordingId.equals(recordingId))
            ..orderBy([(s) => OrderingTerm.asc(s.startMs)]))
          .watch();

  /// Returns the new marker id.
  Future<Result<int>> addMarker(MarkersCompanion marker) =>
      guardDb(() => into(markers).insert(marker));

  Future<Result<void>> deleteMarker(int id) => guardAffected(
    () => (delete(markers)..where((m) => m.id.equals(id))).go(),
  );

  Stream<List<MarkerRow>> watchMarkers(String recordingId) =>
      (select(markers)
            ..where((m) => m.recordingId.equals(recordingId))
            ..orderBy([(m) => OrderingTerm.asc(m.atMs)]))
          .watch();

  /// Inserts or updates the speaker with the same `(recordingId, label)`.
  Future<Result<void>> upsertSpeaker(SpeakersCompanion speaker) => guardDb(
    () => into(speakers).insert(
      speaker,
      onConflict: DoUpdate(
        (_) => speaker,
        target: [speakers.recordingId, speakers.label],
      ),
    ),
  );

  Stream<List<SpeakerRow>> watchSpeakers(String recordingId) =>
      (select(speakers)
            ..where((s) => s.recordingId.equals(recordingId))
            ..orderBy([(s) => OrderingTerm.asc(s.label)]))
          .watch();
}
