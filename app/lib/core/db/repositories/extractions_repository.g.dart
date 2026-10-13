// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extractions_repository.dart';

// ignore_for_file: type=lint
mixin _$ExtractionsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $ExtractionsTable get extractions => attachedDatabase.extractions;
  $ActionItemsTable get actionItems => attachedDatabase.actionItems;
  ExtractionsRepositoryManager get managers =>
      ExtractionsRepositoryManager(this);
}

class ExtractionsRepositoryManager {
  final _$ExtractionsRepositoryMixin _db;
  ExtractionsRepositoryManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$ExtractionsTableTableManager get extractions =>
      $$ExtractionsTableTableManager(_db.attachedDatabase, _db.extractions);
  $$ActionItemsTableTableManager get actionItems =>
      $$ActionItemsTableTableManager(_db.attachedDatabase, _db.actionItems);
}
