// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// A user-granted vault folder (SAF tree URI or iOS bookmark, base64).
@DataClassName('VaultTargetRow')
class VaultTargets extends Table {
  TextColumn get id => text()();
  TextColumn get platform => textEnum<VaultPlatform>()();
  TextColumn get displayName => text()();
  TextColumn get handle => text()();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Routes a note to a target; lower `priority` is evaluated first.
@DataClassName('RoutingRuleRow')
class RoutingRules extends Table {
  TextColumn get id => text()();
  IntColumn get priority => integer()();
  TextColumn get match => text().map(const JsonMapConverter())();
  TextColumn get targetId =>
      text().references(VaultTargets, #id, onDelete: KeyAction.cascade)();
  TextColumn get subPath => text().withDefault(const Constant(''))();
  TextColumn get filenamePattern => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One Markdown export of a recording to a target (outbox row).
@DataClassName('ExportRow')
class Exports extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetId =>
      text().references(VaultTargets, #id, onDelete: KeyAction.cascade)();
  TextColumn get relPath => text()();
  TextColumn get contentHash => text()();
  TextColumn get status => textEnum<ExportStatus>()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {recordingId, targetId},
  ];
}
