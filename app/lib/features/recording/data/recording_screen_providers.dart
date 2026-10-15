import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_session_service.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'recording_screen_providers.g.dart';

/// The open recording (id + recorded time) for markers and the details
/// sheet; null when the capture backend does not expose it (test fakes).
@riverpod
ActiveRecording? activeRecording(Ref ref) {
  final capture = ref.watch(captureBackendProvider);
  return capture is ActiveRecording ? capture as ActiveRecording : null;
}

/// Writes the recording screen's choices (AUD-08).
@Riverpod(keepAlive: true)
RecordingSessionService recordingSessionService(Ref ref) =>
    RecordingSessionService(
      recordings: ref.watch(recordingsRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
      // FND-05 PipelineClient (on main). FND-11 may later own this wiring.
      enqueue: (id, {userInitiated = false}) async {
        final client = await ref.read(pipelineClientProvider.future);
        await client.enqueue(id, userInitiated: userInitiated);
      },
    );

/// Profiles to pre-select (Auto is implicit). Empty when the registry is
/// unavailable — the screen then offers Auto only.
@riverpod
Stream<List<ProfileChoice>> profileChoices(Ref ref) async* {
  final ProfileRegistry registry;
  try {
    registry = await ref.watch(profileRegistryProvider.future);
  } on Object {
    yield const [];
    return;
  }
  yield* registry.watchAll().map(
    (profiles) => [
      for (final p in profiles)
        ProfileChoice(
          id: p.id,
          name: p.name,
          consentRequired:
              p.consentConfirmation == ConsentConfirmation.required,
        ),
    ],
  );
}

/// Vault folders to send the note to (Auto = routing rules).
@riverpod
Future<List<DestinationChoice>> destinationChoices(Ref ref) async {
  final targets = await ref.watch(vaultTargetsProvider.future);
  return [for (final t in targets) DestinationChoice(id: t.id, name: t.name)];
}
