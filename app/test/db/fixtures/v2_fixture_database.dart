import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/migrations.dart';
import 'package:vaultvoice/core/db/tables/export_tables.dart';
import 'package:vaultvoice/core/db/tables/extraction_tables.dart';
import 'package:vaultvoice/core/db/tables/job_tables.dart';
import 'package:vaultvoice/core/db/tables/mind_map_tables.dart';
import 'package:vaultvoice/core/db/tables/profile_tables.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';
import 'package:vaultvoice/core/db/tables/settings_tables.dart';
import 'package:vaultvoice/core/db/tables/transcript_tables.dart';

part 'v2_fixture_database.g.dart';

/// A hypothetical v2 table: labels derived from existing recordings.
@DataClassName('RecordingLabelRow')
class RecordingLabels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
}

/// The step to this fixture's (next) version: create the new table and
/// backfill it from existing data.
Future<void> migrateV1ToV2(Migrator m, GeneratedDatabase db) async {
  final fixture = db as V2FixtureDatabase;
  await m.createTable(fixture.recordingLabels);
  await db.customStatement(
    'INSERT INTO recording_labels (recording_id, label) '
    "SELECT id, 'imported' FROM recordings WHERE source = 'imported'",
  );
}

/// "Next version" of the VaultVoice schema used by the migration tests: every
/// current table plus [RecordingLabels], migrated with the production
/// [buildMigrationStrategy] and the production steps + [migrateV1ToV2].
@DriftDatabase(
  tables: [
    Recordings,
    AudioChunks,
    SpeechSegments,
    Markers,
    Speakers,
    Transcripts,
    TranscriptSegments,
    Jobs,
    Profiles,
    Templates,
    Extractions,
    ActionItems,
    MindMaps,
    VaultTargets,
    RoutingRules,
    Exports,
    ModelsInstalled,
    Settings,
    RecordingLabels,
  ],
  include: {'package:vaultvoice/core/db/tables/search.drift'},
)
class V2FixtureDatabase extends _$V2FixtureDatabase {
  V2FixtureDatabase(super.e, {Map<int, SchemaStep>? steps})
    : _steps =
          steps ??
          {
            ...VaultVoiceDatabase.migrationSteps,
            VaultVoiceDatabase.currentSchemaVersion + 1: migrateV1ToV2,
          };

  final Map<int, SchemaStep> _steps;

  @override
  int get schemaVersion => VaultVoiceDatabase.currentSchemaVersion + 1;

  @override
  MigrationStrategy get migration =>
      buildMigrationStrategy(this, steps: _steps);
}
