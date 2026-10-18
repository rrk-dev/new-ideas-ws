// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// One Ask conversation (ASK-03, ADR-ASK-02). `recordingId` is set for a
/// per-recording Ask; deleting that recording deletes the thread.
@DataClassName('AskThreadRow')
class AskThreads extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId => text().nullable().references(
    Recordings,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();
  IntColumn get updatedAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// One question and its answer. Both texts live only in the encrypted
/// database and are never logged.
@DataClassName('AskTurnRow')
class AskTurns extends Table {
  TextColumn get id => text()();
  TextColumn get threadId =>
      text().references(AskThreads, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  BoolColumn get found => boolean()();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {threadId, seq},
  ];
}

/// A citation is a reference (recording + time), never a text copy. A
/// trigger (`ask.drift`) removes the whole turn when one of its cited
/// recordings goes away, so no answer outlives its sources.
@DataClassName('AskCitationRow')
class AskCitations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get turnId =>
      text().references(AskTurns, #id, onDelete: KeyAction.cascade)();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  IntColumn get tMs => integer()();
}
