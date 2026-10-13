import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/job_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'jobs_repository.g.dart';

/// Persisted pipeline jobs (FND-05 orchestrator state).
@DriftAccessor(tables: [Jobs])
class JobsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$JobsRepositoryMixin {
  JobsRepository(super.attachedDatabase);

  Future<Result<void>> create(JobsCompanion job) =>
      guardDb(() => into(jobs).insert(job));

  Future<Result<JobRow>> get(String id) => guardRow(
    () => (select(jobs)..where((j) => j.id.equals(id))).getSingleOrNull(),
  );

  Stream<JobRow?> watch(String id) =>
      (select(jobs)..where((j) => j.id.equals(id))).watchSingleOrNull();

  /// All jobs, highest priority then oldest first (queue order).
  Stream<List<JobRow>> watchAll() => _ordered().watch();

  Stream<List<JobRow>> watchForRecording(String recordingId) =>
      (_ordered()..where((j) => j.recordingId.equals(recordingId))).watch();

  /// Jobs whose status is one of [statuses], in queue order.
  Future<Result<List<JobRow>>> findByStatus(Set<String> statuses) =>
      guardDb(() => (_ordered()..where((j) => j.status.isIn(statuses))).get());

  SimpleSelectStatement<$JobsTable, JobRow> _ordered() =>
      select(jobs)..orderBy([
        (j) => OrderingTerm.desc(j.priority),
        (j) => OrderingTerm.asc(j.createdAt),
        (j) => OrderingTerm.asc(j.id),
      ]);

  /// Applies the non-absent fields of [patch].
  Future<Result<void>> updateFields(String id, JobsCompanion patch) =>
      guardAffected(
        () => (update(jobs)..where((j) => j.id.equals(id))).write(patch),
      );

  Future<Result<void>> deleteById(String id) =>
      guardAffected(() => (delete(jobs)..where((j) => j.id.equals(id))).go());
}
