// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_repository.dart';

// ignore_for_file: type=lint
mixin _$VaultRepositoryMixin on DatabaseAccessor<VaultVoiceDatabase> {
  $VaultTargetsTable get vaultTargets => attachedDatabase.vaultTargets;
  $RoutingRulesTable get routingRules => attachedDatabase.routingRules;
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $ExportsTable get exports => attachedDatabase.exports;
  VaultRepositoryManager get managers => VaultRepositoryManager(this);
}

class VaultRepositoryManager {
  final _$VaultRepositoryMixin _db;
  VaultRepositoryManager(this._db);
  $$VaultTargetsTableTableManager get vaultTargets =>
      $$VaultTargetsTableTableManager(_db.attachedDatabase, _db.vaultTargets);
  $$RoutingRulesTableTableManager get routingRules =>
      $$RoutingRulesTableTableManager(_db.attachedDatabase, _db.routingRules);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$ExportsTableTableManager get exports =>
      $$ExportsTableTableManager(_db.attachedDatabase, _db.exports);
}
