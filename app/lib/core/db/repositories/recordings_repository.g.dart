// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recordings_repository.dart';

// ignore_for_file: type=lint
mixin _$RecordingsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $AudioChunksTable get audioChunks => attachedDatabase.audioChunks;
  $SpeechSegmentsTable get speechSegments => attachedDatabase.speechSegments;
  $MarkersTable get markers => attachedDatabase.markers;
  $SpeakersTable get speakers => attachedDatabase.speakers;
  RecordingsRepositoryManager get managers => RecordingsRepositoryManager(this);
}

class RecordingsRepositoryManager {
  final _$RecordingsRepositoryMixin _db;
  RecordingsRepositoryManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$AudioChunksTableTableManager get audioChunks =>
      $$AudioChunksTableTableManager(_db.attachedDatabase, _db.audioChunks);
  $$SpeechSegmentsTableTableManager get speechSegments =>
      $$SpeechSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.speechSegments,
      );
  $$MarkersTableTableManager get markers =>
      $$MarkersTableTableManager(_db.attachedDatabase, _db.markers);
  $$SpeakersTableTableManager get speakers =>
      $$SpeakersTableTableManager(_db.attachedDatabase, _db.speakers);
}
