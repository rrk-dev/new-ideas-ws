import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.steps.dart';

/// v4 → v5 (TSK-02): adds the `reminder_exports` table from the frozen v5
/// snapshot (`database.steps.dart`). Additive: existing rows are untouched.
Future<void> migrateToV5ReminderExports(
  Migrator m,
  GeneratedDatabase db,
) async {
  final schema = Schema5(database: db);
  await Migrator(db, schema).createTable(schema.reminderExports);
}
