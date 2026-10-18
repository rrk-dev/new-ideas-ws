// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// Validated mind-map tree of a recording (MAP-01). One map per recording:
/// the id is `<recordingId>.mindmap` and writes replace it, so a retried step
/// never leaves a duplicate. `extractionId` is not a foreign key: the map
/// survives an extraction being replaced. Not part of `search_index`
/// (ADR-MAP-01).
@DataClassName('MindMapRow')
class MindMaps extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get extractionId => text().nullable()();
  TextColumn get method => text()();
  TextColumn get modelId => text().nullable()();
  TextColumn get json => text().map(const JsonMapConverter())();
  IntColumn get nodeCount => integer()();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {id};
}
