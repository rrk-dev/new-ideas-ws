import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/tables/export_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'vault_repository.g.dart';

/// Vault targets, routing rules and the export outbox.
@DriftAccessor(tables: [VaultTargets, RoutingRules, Exports])
class VaultRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$VaultRepositoryMixin {
  VaultRepository(super.attachedDatabase);

  Future<Result<void>> upsertTarget(VaultTargetsCompanion target) =>
      guardDb(() => into(vaultTargets).insertOnConflictUpdate(target));

  Future<Result<VaultTargetRow>> getTarget(String id) => guardRow(
    () =>
        (select(vaultTargets)..where((t) => t.id.equals(id))).getSingleOrNull(),
  );

  Stream<List<VaultTargetRow>> watchTargets() =>
      (select(vaultTargets)..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  /// Also deletes the target's routing rules and export rows.
  Future<Result<void>> deleteTarget(String id) => guardAffected(
    () => (delete(vaultTargets)..where((t) => t.id.equals(id))).go(),
  );

  Future<Result<void>> upsertRule(RoutingRulesCompanion rule) =>
      guardDb(() => into(routingRules).insertOnConflictUpdate(rule));

  /// Evaluation order: lowest priority first.
  Stream<List<RoutingRuleRow>> watchRules() =>
      (select(routingRules)..orderBy([
            (r) => OrderingTerm.asc(r.priority),
            (r) => OrderingTerm.asc(r.id),
          ]))
          .watch();

  Future<Result<void>> deleteRule(String id) => guardAffected(
    () => (delete(routingRules)..where((r) => r.id.equals(id))).go(),
  );

  /// Inserts or updates the export row of `(recordingId, targetId)`.
  Future<Result<void>> upsertExport(ExportsCompanion export) => guardDb(
    () => into(exports).insert(
      export,
      onConflict: DoUpdate(
        (_) => export,
        target: [exports.recordingId, exports.targetId],
      ),
    ),
  );

  Future<Result<ExportRow>> getExport(String id) => guardRow(
    () => (select(exports)..where((e) => e.id.equals(id))).getSingleOrNull(),
  );

  /// Exports of a recording, or every export when [recordingId] is null.
  Stream<List<ExportRow>> watchExports({
    String? recordingId,
    Set<ExportStatus>? statuses,
  }) {
    final query = select(exports)
      ..orderBy([
        (e) => OrderingTerm.asc(e.updatedAt),
        (e) => OrderingTerm.asc(e.id),
      ]);
    if (recordingId != null) {
      query.where((e) => e.recordingId.equals(recordingId));
    }
    if (statuses != null) {
      query.where((e) => e.status.isIn([for (final s in statuses) s.name]));
    }
    return query.watch();
  }

  Future<Result<void>> updateExport(String id, ExportsCompanion patch) =>
      guardAffected(
        () => (update(exports)..where((e) => e.id.equals(id))).write(patch),
      );

  Future<Result<void>> deleteExport(String id) => guardAffected(
    () => (delete(exports)..where((e) => e.id.equals(id))).go(),
  );
}
