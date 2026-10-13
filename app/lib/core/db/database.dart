import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/migrations.dart';
import 'package:vaultvoice/core/db/repositories/extractions_repository.dart';
import 'package:vaultvoice/core/db/repositories/jobs_repository.dart';
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/db/repositories/transcripts_repository.dart';
import 'package:vaultvoice/core/db/repositories/vault_repository.dart';
import 'package:vaultvoice/core/db/tables/export_tables.dart';
import 'package:vaultvoice/core/db/tables/extraction_tables.dart';
import 'package:vaultvoice/core/db/tables/job_tables.dart';
import 'package:vaultvoice/core/db/tables/profile_tables.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';
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
    VaultTargets,
    RoutingRules,
    Exports,
    ModelsInstalled,
    Settings,
  ],
  daos: [
    RecordingsRepository,
    TranscriptsRepository,
    JobsRepository,
    ProfilesRepository,
    ExtractionsRepository,
    VaultRepository,
    ModelsRepository,
    SettingsRepository,
  ],
)
class VaultVoiceDatabase extends _$VaultVoiceDatabase {
  VaultVoiceDatabase(super.e);

  /// Current schema version. Bump together with a registered step in
  /// [migrationSteps] and `drift_dev make-migrations`.
  static const int currentSchemaVersion = 1;

  /// Upgrade steps keyed by target version (none yet: v1 is the first).
  static const Map<int, SchemaStep> migrationSteps = {};

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration =>
      buildMigrationStrategy(this, steps: migrationSteps);
}
