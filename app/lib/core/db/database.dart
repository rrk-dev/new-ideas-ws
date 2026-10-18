import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/ask_migration.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/migrations.dart';
import 'package:vaultvoice/core/db/mind_map_migration.dart';
import 'package:vaultvoice/core/db/reminder_migration.dart';
import 'package:vaultvoice/core/db/repositories/extractions_repository.dart';
import 'package:vaultvoice/core/db/repositories/jobs_repository.dart';
import 'package:vaultvoice/core/db/repositories/mind_maps_repository.dart';
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/repositories/reminder_exports_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/db/repositories/transcripts_repository.dart';
import 'package:vaultvoice/core/db/repositories/vault_repository.dart';
import 'package:vaultvoice/core/db/search_migration.dart';
import 'package:vaultvoice/core/db/tables/ask_tables.dart';
import 'package:vaultvoice/core/db/tables/export_tables.dart';
import 'package:vaultvoice/core/db/tables/extraction_tables.dart';
import 'package:vaultvoice/core/db/tables/job_tables.dart';
import 'package:vaultvoice/core/db/tables/mind_map_tables.dart';
import 'package:vaultvoice/core/db/tables/profile_tables.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';
import 'package:vaultvoice/core/db/tables/reminder_tables.dart';
import 'package:vaultvoice/core/db/tables/settings_tables.dart';
import 'package:vaultvoice/core/db/tables/transcript_tables.dart';

part 'database.g.dart';

/// The app's metadata store (ADR-FND-04: drift on SQLite).
///
/// Open it with `openDatabaseFile` (production) or `NativeDatabase.memory()`
/// (tests). Schema changes: see `migrations.dart`.
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
    AskThreads,
    AskTurns,
    AskCitations,
    ReminderExports,
  ],
  // APP-02: FTS5 search index + the triggers that keep it in sync.
  include: {'tables/search.drift', 'tables/ask.drift'},
  daos: [
    RecordingsRepository,
    TranscriptsRepository,
    JobsRepository,
    ProfilesRepository,
    ExtractionsRepository,
    MindMapsRepository,
    VaultRepository,
    ModelsRepository,
    SettingsRepository,
    ReminderExportsRepository,
  ],
)
class VaultVoiceDatabase extends _$VaultVoiceDatabase {
  VaultVoiceDatabase(super.e);

  /// Current schema version. Bump together with a registered step in
  /// [migrationSteps] and `drift_dev make-migrations`.
  static const int currentSchemaVersion = 5;

  /// Upgrade steps keyed by target version.
  static const Map<int, SchemaStep> migrationSteps = {
    // APP-02: full-text search index (+ backfill).
    2: migrateToV2SearchIndex,
    // MAP-01: mind_maps table (additive).
    3: migrateToV3MindMaps,
    // ASK-03: chat history tables + citation triggers.
    4: migrateToV4Ask,
    // TSK-02: reminder_exports table (additive).
    5: migrateToV5ReminderExports,
  };

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration =>
      buildMigrationStrategy(this, steps: migrationSteps);
}
