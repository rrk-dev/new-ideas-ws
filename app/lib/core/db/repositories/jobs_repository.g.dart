// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jobs_repository.dart';

// ignore_for_file: type=lint
mixin _$JobsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $JobsTable get jobs => attachedDatabase.jobs;
  JobsRepositoryManager get managers => JobsRepositoryManager(this);
}

class JobsRepositoryManager {
  final _$JobsRepositoryMixin _db;
  JobsRepositoryManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$JobsTableTableManager get jobs =>
      $$JobsTableTableManager(_db.attachedDatabase, _db.jobs);
}
