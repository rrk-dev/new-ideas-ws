// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profiles_repository.dart';

// ignore_for_file: type=lint
mixin _$ProfilesRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $ProfilesTable get profiles => attachedDatabase.profiles;
  $TemplatesTable get templates => attachedDatabase.templates;
  ProfilesRepositoryManager get managers => ProfilesRepositoryManager(this);
}

class ProfilesRepositoryManager {
  final _$ProfilesRepositoryMixin _db;
  ProfilesRepositoryManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db.attachedDatabase, _db.templates);
}
