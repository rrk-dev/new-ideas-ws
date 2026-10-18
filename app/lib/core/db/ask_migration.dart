import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.steps.dart';

/// v3 → v4 (ASK-03): Ask chat history tables and the triggers that remove a
/// turn when one of its cited recordings goes away, from the frozen v4
/// snapshot. Shipped steps are never edited.
Future<void> migrateToV4Ask(Migrator m, GeneratedDatabase db) async {
  final schema = Schema4(database: db);
  final migrator = Migrator(db, schema);
  await migrator.create(schema.askThreads);
  await migrator.create(schema.askTurns);
  await migrator.create(schema.askCitations);
  await migrator.create(schema.askCitationDelete);
  await migrator.create(schema.askTurnDelete);
}
