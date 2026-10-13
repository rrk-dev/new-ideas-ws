// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models_repository.dart';

// ignore_for_file: type=lint
mixin _$ModelsRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $ModelsInstalledTable get modelsInstalled => attachedDatabase.modelsInstalled;
  ModelsRepositoryManager get managers => ModelsRepositoryManager(this);
}

class ModelsRepositoryManager {
  final _$ModelsRepositoryMixin _db;
  ModelsRepositoryManager(this._db);
  $$ModelsInstalledTableTableManager get modelsInstalled =>
      $$ModelsInstalledTableTableManager(
        _db.attachedDatabase,
        _db.modelsInstalled,
      );
}
