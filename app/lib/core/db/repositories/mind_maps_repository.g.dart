// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mind_maps_repository.dart';

// ignore_for_file: type=lint
mixin _$MindMapsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $MindMapsTable get mindMaps => attachedDatabase.mindMaps;
  MindMapsRepositoryManager get managers => MindMapsRepositoryManager(this);
}

class MindMapsRepositoryManager {
  final _$MindMapsRepositoryMixin _db;
  MindMapsRepositoryManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$MindMapsTableTableManager get mindMaps =>
      $$MindMapsTableTableManager(_db.attachedDatabase, _db.mindMaps);
}
