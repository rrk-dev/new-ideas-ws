// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// Structured LLM output for a recording under one profile version.
/// `profileId` is not a foreign key: the extraction must survive the profile
/// being edited or deleted.
@DataClassName('ExtractionRow')
class Extractions extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get profileId => text()();
  IntColumn get profileVersion => integer()();
  TextColumn get modelId => text()();
  TextColumn get json => text().map(const JsonMapConverter())();
  BoolColumn get valid => boolean()();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Action item rendered from an extraction (APP-02 cross-recording task view).
@DataClassName('ActionItemRow')
class ActionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get extractionId =>
      text().references(Extractions, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text()();
  TextColumn get owner => text().nullable()();
  TextColumn get dueIso => text().nullable()();
  IntColumn get tMs => integer().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get doneAt => integer().map(const EpochMsConverter()).nullable()();
}
