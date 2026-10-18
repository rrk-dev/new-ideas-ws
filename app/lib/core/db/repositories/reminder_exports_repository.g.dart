// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_exports_repository.dart';

// ignore_for_file: type=lint
mixin _$ReminderExportsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $ReminderExportsTable get reminderExports => attachedDatabase.reminderExports;
  ReminderExportsRepositoryManager get managers =>
      ReminderExportsRepositoryManager(this);
}

class ReminderExportsRepositoryManager {
  final _$ReminderExportsRepositoryMixin _db;
  ReminderExportsRepositoryManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$ReminderExportsTableTableManager get reminderExports =>
      $$ReminderExportsTableTableManager(
        _db.attachedDatabase,
        _db.reminderExports,
      );
}
