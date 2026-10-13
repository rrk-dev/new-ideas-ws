import 'package:drift/drift.dart';

/// Upgrades the schema from `version - 1` to the version it is registered
/// under.
///
/// New versions: bump `schemaVersion`, run
/// `fvm dart run drift_dev make-migrations`, then register a step here that
/// uses the generated `database.steps.dart` snapshot for that version (e.g.
/// `(m, db) => m.addColumn(schema.recordings, schema.recordings.language)`).
/// Never edit a step that has shipped.
typedef SchemaStep = Future<void> Function(Migrator m, GeneratedDatabase db);

/// Raised when an upgrade cannot run (missing step) or leaves the database
/// inconsistent. Opening the database fails rather than silently continuing
/// with a half-migrated schema.
class MigrationException implements Exception {
  const MigrationException(this.message);

  final String message;

  @override
  String toString() => 'MigrationException($message)';
}

/// The migration policy shared by the app database and migration fixtures:
/// create everything on first open, run registered [steps] in order inside a
/// transaction on upgrade, refuse downgrades, verify foreign keys afterwards
/// and enable foreign-key enforcement on every open.
MigrationStrategy buildMigrationStrategy(
  GeneratedDatabase db, {
  required Map<int, SchemaStep> steps,
}) {
  return MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (to < from) {
        throw MigrationException('downgrade $from -> $to is not supported');
      }
      // Table rebuilds need FKs off; this must happen outside a transaction.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.transaction(() async {
        for (var version = from + 1; version <= to; version++) {
          final step = steps[version];
          if (step == null) {
            throw MigrationException('no migration step to v$version');
          }
          await step(m, db);
        }
      });
      final broken = await db.customSelect('PRAGMA foreign_key_check').get();
      if (broken.isNotEmpty) {
        throw MigrationException(
          'foreign key check failed after $from -> $to '
          '(${broken.length} rows)',
        );
      }
    },
    beforeOpen: (details) async {
      await db.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
