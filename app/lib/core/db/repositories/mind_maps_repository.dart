import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/mind_map_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'mind_maps_repository.g.dart';

/// Mind maps (MAP-01): at most one per recording.
@DriftAccessor(tables: [MindMaps])
class MindMapsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$MindMapsRepositoryMixin {
  MindMapsRepository(super.attachedDatabase);

  static String idFor(String recordingId) => '$recordingId.mindmap';

  /// Inserts or replaces the recording's map.
  Future<Result<void>> upsert(MindMapsCompanion map) =>
      guardDb(() => into(mindMaps).insertOnConflictUpdate(map));

  Future<Result<MindMapRow?>> forRecording(String recordingId) => guardDb(
    () => (select(
      mindMaps,
    )..where((m) => m.recordingId.equals(recordingId))).getSingleOrNull(),
  );

  Stream<MindMapRow?> watchForRecording(String recordingId) => (select(
    mindMaps,
  )..where((m) => m.recordingId.equals(recordingId))).watchSingleOrNull();

  Future<Result<void>> deleteForRecording(String recordingId) =>
      guardDb(() async {
        await (delete(
          mindMaps,
        )..where((m) => m.recordingId.equals(recordingId))).go();
      });
}
