// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// A transcript of a recording produced by one STT model run.
@DataClassName('TranscriptRow')
class Transcripts extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get modelId => text()();
  TextColumn get language => text()();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One timed segment. `(transcriptId, seq)` is unique so re-running a chunk
/// overwrites instead of duplicating (pipeline idempotency).
@DataClassName('TranscriptSegmentRow')
class TranscriptSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transcriptId =>
      text().references(Transcripts, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get speaker => text().nullable()();
  TextColumn get body => text()();
  TextColumn get originalText => text().nullable()();
  RealColumn get avgLogprob => real().nullable()();

  /// `[{text,p,t0_ms,t1_ms}]` for low-confidence highlighting (STT-06).
  TextColumn get tokensJson => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {transcriptId, seq},
  ];
}
