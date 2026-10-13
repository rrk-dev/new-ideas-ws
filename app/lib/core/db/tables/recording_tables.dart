// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/enums.dart';

/// One captured or imported recording. `id` is a UUID string.
@DataClassName('RecordingRow')
class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer().map(const EpochMsConverter())();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get status => textEnum<RecordingStatus>()();
  TextColumn get source => textEnum<RecordingSource>()();
  TextColumn get profileId => text().nullable()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  IntColumn get consentConfirmedAt =>
      integer().map(const EpochMsConverter()).nullable()();
  IntColumn get importAttestedAt =>
      integer().map(const EpochMsConverter()).nullable()();
  TextColumn get stopReason => textEnum<StopReason>().nullable()();
  BoolColumn get recovered => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A WAV chunk of a recording. `path` is relative to `<appSupport>/vv/`.
@DataClassName('AudioChunkRow')
class AudioChunks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  TextColumn get path => text()();
  IntColumn get sampleRate => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  IntColumn get bytes => integer()();
  TextColumn get sha256 => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {recordingId, seq},
  ];
}

/// Voice-activity span detected by VAD.
@DataClassName('SpeechSegmentRow')
class SpeechSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
}

/// A point on the recording timeline (user bookmark, gap, interruption).
@DataClassName('MarkerRow')
class Markers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  IntColumn get atMs => integer()();
  TextColumn get kind => textEnum<MarkerKind>()();
  TextColumn get label => text().nullable()();
}

/// Anonymous speaker of a recording (no voiceprints — SEC-09).
@DataClassName('SpeakerRow')
class Speakers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  TextColumn get displayName => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {recordingId, label},
  ];
}
