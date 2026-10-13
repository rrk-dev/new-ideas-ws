import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/profile_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'profiles_repository.g.dart';

/// Extraction profiles and Markdown templates.
@DriftAccessor(tables: [Profiles, Templates])
class ProfilesRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$ProfilesRepositoryMixin {
  ProfilesRepository(super.attachedDatabase);

  /// Inserts or replaces the profile with the same id.
  Future<Result<void>> upsertProfile(ProfilesCompanion profile) =>
      guardDb(() => into(profiles).insertOnConflictUpdate(profile));

  Future<Result<ProfileRow>> getProfile(String id) => guardRow(
    () => (select(profiles)..where((p) => p.id.equals(id))).getSingleOrNull(),
  );

  Stream<List<ProfileRow>> watchProfiles() =>
      (select(profiles)..orderBy([(p) => OrderingTerm.asc(p.id)])).watch();

  /// Deleting a profile keeps its templates (their `profileId` becomes null).
  Future<Result<void>> deleteProfile(String id) => guardAffected(
    () => (delete(profiles)..where((p) => p.id.equals(id))).go(),
  );

  Future<Result<void>> upsertTemplate(TemplatesCompanion template) =>
      guardDb(() => into(templates).insertOnConflictUpdate(template));

  Future<Result<TemplateRow>> getTemplate(String id) => guardRow(
    () => (select(templates)..where((t) => t.id.equals(id))).getSingleOrNull(),
  );

  /// Templates bound to [profileId], or all templates when it is null.
  Stream<List<TemplateRow>> watchTemplates({String? profileId}) {
    final query = select(templates)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    if (profileId != null) query.where((t) => t.profileId.equals(profileId));
    return query.watch();
  }

  Future<Result<void>> deleteTemplate(String id) => guardAffected(
    () => (delete(templates)..where((t) => t.id.equals(id))).go(),
  );
}
