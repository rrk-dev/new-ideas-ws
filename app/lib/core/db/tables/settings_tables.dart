// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/enums.dart';

/// An installed model file. `path` is relative to `<appSupport>/vv/`.
@DataClassName('InstalledModelRow')
class ModelsInstalled extends Table {
  @override
  String get tableName => 'models_installed';

  TextColumn get id => text()();
  TextColumn get type => textEnum<ModelType>()();
  TextColumn get version => text()();
  TextColumn get path => text()();
  TextColumn get sha256 => text()();
  IntColumn get size => integer()();
  IntColumn get installedAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key/value app settings; `value` is JSON.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
