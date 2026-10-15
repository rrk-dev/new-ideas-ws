import 'dart:async';

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

/// Ticks whenever the extractions or jobs of [recordingId] change, so share
/// availability is recomputed once processing finishes.
@riverpod
Stream<int> recordingNoteChanges(Ref ref, String recordingId) {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final extractions = (db.select(
    db.extractions,
  )..where((e) => e.recordingId.equals(recordingId))).watch();
  final jobs = (db.select(
    db.jobs,
  )..where((j) => j.recordingId.equals(recordingId))).watch();
  var n = 0;
  final out = StreamController<int>();
  final subs = [
    extractions.listen((_) => out.add(n++)),
    jobs.listen((_) => out.add(n++)),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
    unawaited(out.close());
  });
  return out.stream;
}

/// Formats the note of [recordingId] can be shared in (empty: no note).
@riverpod
Future<Set<TemplateFlavor>> shareableFormats(
  Ref ref,
  String recordingId,
) async {
  ref.watch(recordingNoteChangesProvider(recordingId));
  final sharing = await ref.watch(noteSharingProvider.future);
  return await sharing.available(recordingId);
}
