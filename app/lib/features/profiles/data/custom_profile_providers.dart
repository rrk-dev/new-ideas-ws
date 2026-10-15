import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_service.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';

part 'custom_profile_providers.g.dart';

/// Every profile for the Profiles tab: built-ins (assets) then stored
/// user/enterprise profiles (rows that no longer validate are skipped).
/// Needs no grammar converter, so it works before LLM-05 is wired.
@riverpod
Stream<List<Profile>> profileList(Ref ref) async* {
  final builtins = await ref.watch(builtinProfilesProvider.future);
  final dao = ref.watch(profilesRepositoryProvider);
  const validator = ProfileValidator();
  await for (final rows in dao.watchProfiles()) {
    yield [
      ...builtins.all,
      for (final row in rows)
        ?validator.validate(row.definition, source: row.source).profile,
    ];
  }
}

/// One profile by id (editor).
@riverpod
Future<Profile?> profileById(Ref ref, String id) async {
  final all = await ref.watch(profileListProvider.future);
  for (final p in all) {
    if (p.id == id) return p;
  }
  return null;
}

/// Whether custom profiles can be created / edited (LIC-01).
@riverpod
bool canEditProfiles(Ref ref) =>
    ref.watch(featureProvider(Feature.customProfiles));

/// Every dependency is watched before the first await (the provider may be
/// disposed once its future completes); an entitlement change rebuilds it.
@riverpod
Future<CustomProfileService> customProfileService(Ref ref) async {
  final dao = ref.watch(profilesRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final canEdit = ref.watch(canEditProfilesProvider);
  final registry = ref.watch(profileRegistryProvider.future);
  return CustomProfileService(
    registry: await registry,
    dao: dao,
    canEdit: () => canEdit,
    clock: clock,
  );
}

@riverpod
Future<ProfilePreview> profilePreview(Ref ref) async {
  final llm = ref.watch(llmEngineProvider);
  final registry = await ref.watch(profileRegistryProvider.future);
  return ProfilePreview(
    llm: llm,
    grammarFor: (p) async => switch (await registry.grammarsFor(p)) {
      Ok(:final value) => Ok(value.schema),
      Err(:final failure) => Err(failure),
    },
    appVersion: kAppVersion,
  );
}

/// Recordings that can be used for "Test on a recording".
@riverpod
Stream<List<PreviewRecording>> previewRecordings(Ref ref) => ref
    .watch(recordingsRepositoryProvider)
    .watchAll()
    .map(
      (rows) => [
        for (final r in rows)
          PreviewRecording(id: r.id, title: r.title, createdAt: r.createdAt),
      ],
    );

/// The latest transcript of [recordingId] as prompt input (empty when none).
@riverpod
Future<PromptInputParts> previewInput(Ref ref, String recordingId) async {
  final recordings = ref.watch(recordingsRepositoryProvider);
  final transcripts = ref.watch(transcriptsRepositoryProvider);
  final rec = (await recordings.get(recordingId)).valueOrNull;
  final transcript = (await transcripts.latestFor(recordingId)).valueOrNull;
  final rows = transcript == null
      ? null
      : (await transcripts.segments(transcript.id)).valueOrNull;
  return PromptInputParts(
    metadata: PromptMetadata(
      recordedAt: (rec?.createdAt ?? DateTime(2026)).toLocal(),
      duration: Duration(milliseconds: rec?.durationMs ?? 0),
    ),
    segments: [
      for (final s in rows ?? const <TranscriptSegmentRow>[])
        PromptSegment(
          start: Duration(milliseconds: s.startMs),
          speaker: s.speaker,
          text: s.body,
        ),
    ],
  );
}
