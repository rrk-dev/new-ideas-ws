import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/tables/settings_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'models_repository.g.dart';

/// Installed model files (MDL-02 writes, engines read).
@DriftAccessor(tables: [ModelsInstalled])
class ModelsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$ModelsRepositoryMixin {
  ModelsRepository(super.attachedDatabase);

  /// Inserts or replaces the model with the same id (atomic reinstall).
  Future<Result<void>> upsert(ModelsInstalledCompanion model) =>
      guardDb(() => into(modelsInstalled).insertOnConflictUpdate(model));

  Future<Result<InstalledModelRow>> get(String id) => guardRow(
    () => (select(
      modelsInstalled,
    )..where((m) => m.id.equals(id))).getSingleOrNull(),
  );

  /// All models, or those of [type].
  Stream<List<InstalledModelRow>> watchAll({ModelType? type}) {
    final query = select(modelsInstalled)
      ..orderBy([(m) => OrderingTerm.asc(m.id)]);
    if (type != null) query.where((m) => m.type.equalsValue(type));
    return query.watch();
  }

  Future<Result<void>> deleteById(String id) => guardAffected(
    () => (delete(modelsInstalled)..where((m) => m.id.equals(id))).go(),
  );
}
