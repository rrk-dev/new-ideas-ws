import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_markdown.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

part 'mind_map_providers.g.dart';

/// The stored mind map of a recording; null when none exists or the stored
/// tree no longer validates (it is then treated as not generated).
@riverpod
Stream<MindMapNode?> recordingMindMap(Ref ref, String recordingId) => ref
    .watch(vaultVoiceDatabaseProvider)
    .mindMapsRepository
    .watchForRecording(recordingId)
    .map((row) => row == null ? null : mindMapFromJson(row.json));

/// True while the user's request for a map is outstanding (set on Generate,
/// cleared by the step when the map is committed or rejected).
@riverpod
Stream<bool> mindMapRequested(Ref ref, String recordingId) => ref
    .watch(settingsRepositoryProvider)
    .watch(SettingKeys.mindMapRequestFor(recordingId))
    .map((v) => v == true);
