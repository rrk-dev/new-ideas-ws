import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/export/data/note_sharing.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

part 'note_sharing_providers.g.dart';

/// Built-in templates parsed from assets once per launch.
@Riverpod(keepAlive: true)
Future<BuiltinTemplates> builtinTemplates(Ref ref) async {
  final load = ref.watch(profileAssetLoaderProvider);
  return BuiltinTemplates.parse({
    for (final t in kBuiltinTemplates) t.assetPath: await load(t.assetPath),
  });
}

@Riverpod(keepAlive: true)
Future<NoteSharing> noteSharing(Ref ref) async => NoteSharing(
  db: ref.watch(vaultVoiceDatabaseProvider),
  paths: await ref.watch(storagePathsProvider.future),
  profiles: await ref.watch(builtinProfilesProvider.future),
  templates: await ref.watch(builtinTemplatesProvider.future),
  appVersion: kAppVersion,
);

/// Formats the note of [recordingId] can be shared in (empty: no note).
@riverpod
Future<Set<TemplateFlavor>> shareableFormats(
  Ref ref,
  String recordingId,
) async {
  final sharing = await ref.watch(noteSharingProvider.future);
  return await sharing.available(recordingId);
}
