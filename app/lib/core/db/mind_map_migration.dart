import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.steps.dart';

/// v2 → v3 (MAP-01): adds the `mind_maps` table from the frozen v3 snapshot
/// (`database.steps.dart`). Additive: existing rows are untouched.
Future<void> migrateToV3MindMaps(Migrator m, GeneratedDatabase db) async {
  final schema = Schema3(database: db);
  await Migrator(db, schema).createTable(schema.mindMaps);
}
