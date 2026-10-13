// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/enums.dart';

/// An extraction profile (PRF-01 owns the `definition` JSON spec).
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  IntColumn get version => integer()();
  TextColumn get source => textEnum<ProfileSource>()();
  TextColumn get definition => text().map(const JsonMapConverter())();
  IntColumn get updatedAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// A Mustache Markdown template, optionally bound to a profile.
@DataClassName('TemplateRow')
class Templates extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().nullable().references(
    Profiles,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get body => text()();
  TextColumn get filenamePattern => text()();
  IntColumn get updatedAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}
