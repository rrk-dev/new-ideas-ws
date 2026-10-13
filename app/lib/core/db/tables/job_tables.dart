// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// A persisted pipeline job (FND-05 owns the `step`/`status` vocabularies;
/// they are stored as plain text so the orchestrator can evolve them).
@DataClassName('JobRow')
class Jobs extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get step => text()();
  TextColumn get status => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Higher runs first ("Process now" jumps the queue).
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();

  /// Content-free detail (failure type), never transcript text or paths.
  TextColumn get errorDetail => text().nullable()();

  /// Reason for a `waiting` job (model_missing, profile_choice, …).
  TextColumn get waitingReason => text().nullable()();

  /// Earliest time an automatic retry may run (backoff).
  IntColumn get notBefore =>
      integer().map(const EpochMsConverter()).nullable()();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();
  IntColumn get updatedAt => integer().map(const EpochMsConverter())();
  TextColumn get checkpoint =>
      text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
