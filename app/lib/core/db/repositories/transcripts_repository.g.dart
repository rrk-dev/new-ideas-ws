// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcripts_repository.dart';

// ignore_for_file: type=lint
mixin _$TranscriptsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $TranscriptsTable get transcripts => attachedDatabase.transcripts;
  $TranscriptSegmentsTable get transcriptSegments =>
      attachedDatabase.transcriptSegments;
  TranscriptsRepositoryManager get managers =>
      TranscriptsRepositoryManager(this);
}

class TranscriptsRepositoryManager {
  final _$TranscriptsRepositoryMixin _db;
  TranscriptsRepositoryManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db.attachedDatabase, _db.transcripts);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.transcriptSegments,
      );
}
