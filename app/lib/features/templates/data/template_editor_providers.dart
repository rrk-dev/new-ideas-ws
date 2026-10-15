import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';
import 'package:vaultvoice/features/templates/data/template_store.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

part 'template_editor_providers.g.dart';

/// Built-in profile ids, from the asset list (no asset load needed).
final Set<String> kBuiltinProfileIds = {
  for (final a in kBuiltinProfileAssets)
    a.substring(a.lastIndexOf('/') + 1, a.lastIndexOf('.')),
};

@Riverpod(keepAlive: true)
TemplateStore templateStore(Ref ref) => DriftTemplateStore(
  templates: ref.watch(profilesRepositoryProvider),
  settings: ref.watch(settingsRepositoryProvider),
  builtinProfileIds: kBuiltinProfileIds,
  clock: ref.watch(clockProvider),
);

/// Custom templates, by id.
@riverpod
Stream<List<CustomTemplate>> customTemplates(Ref ref) =>
    ref.watch(templateStoreProvider).watch();

/// Profile id → bound custom template id.
@riverpod
Stream<Map<String, String>> templateBindings(Ref ref) =>
    ref.watch(templateStoreProvider).watchBindings();

/// Built-in template sources by id (read-only view, duplicate, reset).
@Riverpod(keepAlive: true)
Future<Map<String, String>> builtinTemplateSources(Ref ref) async {
  final load = ref.watch(profileAssetLoaderProvider);
  return {for (final t in kBuiltinTemplates) t.id: await load(t.assetPath)};
}

/// Profiles a template can be written for: built-ins plus valid user /
/// enterprise profiles from the database.
@riverpod
Future<List<Profile>> editorProfiles(Ref ref) async {
  final builtins = await ref.watch(builtinProfilesProvider.future);
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final rows = await (db.select(
    db.profiles,
  )..where((p) => p.source.isNotIn([ProfileSource.builtin.name]))).get();
  const validator = ProfileValidator();
  return [
    ...builtins.all,
    for (final r in rows)
      ?validator.validate(r.definition, source: r.source).profile,
  ];
}

/// One past recording usable as preview data (title is user content:
/// shown, never logged).
class PreviewRecording {
  const PreviewRecording({
    required this.recordingId,
    required this.title,
    required this.createdAt,
    required this.data,
  });

  final String recordingId;
  final String title;
  final DateTime createdAt;
  final Map<String, Object?> data;
}

/// The latest valid extractions of [profileId] (newest first, one per
/// recording, ≤ 10).
@riverpod
Future<List<PreviewRecording>> templatePreviewRecordings(
  Ref ref,
  String profileId,
) async {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final q =
      db.select(db.extractions).join([
          innerJoin(
            db.recordings,
            db.recordings.id.equalsExp(db.extractions.recordingId),
          ),
        ])
        ..where(
          db.extractions.profileId.equals(profileId) &
              db.extractions.valid.equals(true),
        )
        ..orderBy([OrderingTerm.desc(db.extractions.createdAt)]);
  final seen = <String>{};
  return [
    for (final row in await q.get())
      if (seen.add(row.readTable(db.recordings).id))
        PreviewRecording(
          recordingId: row.readTable(db.recordings).id,
          title: row.readTable(db.recordings).title,
          createdAt: row.readTable(db.recordings).createdAt,
          data: row.readTable(db.extractions).json,
        ),
  ].take(10).toList();
}
