import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/reminder_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'reminder_exports_repository.g.dart';

/// Links from action items to the reminders created for them (TSK-02).
@DriftAccessor(tables: [ReminderExports])
class ReminderExportsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$ReminderExportsRepositoryMixin {
  ReminderExportsRepository(super.attachedDatabase);

  /// Links for [keys], by item key.
  Future<Result<Map<String, ReminderExportRow>>> linksFor(
    Iterable<String> keys,
  ) => guardDb(() async {
    final wanted = keys.toList();
    if (wanted.isEmpty) return const {};
    final rows = await (select(
      reminderExports,
    )..where((l) => l.itemKey.isIn(wanted))).get();
    return {for (final r in rows) r.itemKey: r};
  });

  /// Inserts or replaces the link of one item.
  Future<Result<void>> upsert(ReminderExportsCompanion link) =>
      guardDb(() => into(reminderExports).insertOnConflictUpdate(link));

  Future<Result<List<ReminderExportRow>>> forRecording(String recordingId) =>
      guardDb(
        () => (select(
          reminderExports,
        )..where((l) => l.recordingId.equals(recordingId))).get(),
      );
}
