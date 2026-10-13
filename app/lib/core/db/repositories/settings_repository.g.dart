// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_repository.dart';

// ignore_for_file: type=lint
mixin _$SettingsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  SettingsRepositoryManager get managers => SettingsRepositoryManager(this);
}

class SettingsRepositoryManager {
  final _$SettingsRepositoryMixin _db;
  SettingsRepositoryManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
}
