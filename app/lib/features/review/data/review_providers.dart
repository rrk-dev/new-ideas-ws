import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

part 'review_providers.g.dart';

/// Every profile (built-in + user) for the review settings and the form.
@riverpod
Stream<List<Profile>> reviewProfiles(Ref ref) async* {
  final registry = await ref.watch(profileRegistryProvider.future);
  yield* registry.watchAll();
}

/// One profile by id, or null when it no longer exists.
@riverpod
Future<Profile?> reviewProfile(Ref ref, String profileId) async {
  final registry = await ref.watch(profileRegistryProvider.future);
  return (await registry.get(profileId)).valueOrNull;
}

/// Whether [profileId]'s results are reviewed before export.
@riverpod
Future<bool> reviewMode(Ref ref, String profileId) async {
  final setting = await ref.watch(
    storedSettingProvider(ReviewKeys.mode(profileId)).future,
  );
  final profile = await ref.watch(reviewProfileProvider(profileId).future);
  return reviewRequired(
    setting: setting,
    profileDefault: profile?.reviewBeforeExport ?? false,
  );
}

/// Built-in Markdown templates (EXP-01 assets) for the preview.
@Riverpod(keepAlive: true)
Future<BuiltinTemplates> previewTemplates(Ref ref) async =>
    BuiltinTemplates.parse({
      for (final t in kBuiltinTemplates)
        t.assetPath: await rootBundle.loadString(t.assetPath),
    });

/// The note renderer used for the review preview — the same EXP-01
/// renderer the pipeline's RenderStep uses.
@riverpod
Future<NoteRenderer> previewRenderer(Ref ref) async {
  final profiles = await ref.watch(builtinProfilesProvider.future);
  final templates = await ref.watch(previewTemplatesProvider.future);
  final user = await ref.watch(reviewProfilesProvider.future);
  return TemplateNoteRenderer(
    profiles: profiles,
    templates: templates,
    appVersion: kAppVersion,
    userProfiles: {
      for (final p in user)
        if (profiles[p.id] == null) p.id: p,
    },
  ).call;
}

@Riverpod(keepAlive: true)
ReviewService reviewService(Ref ref) => ReviewService(
  db: ref.watch(vaultVoiceDatabaseProvider),
  settings: ref.watch(settingsStoreProvider),
  pipeline: () => ref.read(pipelineClientProvider.future),
);

/// Saves a reviewed result and lets the pipeline export it (APP-05).
class ReviewService {
  ReviewService({
    required this._db,
    required this._settings,
    required this._pipeline,
  });

  final VaultVoiceDatabase _db;
  final SettingsStore _settings;
  final Future<PipelineClient> Function() _pipeline;

  /// Renders [edited] like the pipeline would, without saving anything.
  Future<Result<String>> preview({
    required String recordingId,
    required String extractionId,
    required Map<String, Object?> edited,
    required NoteRenderer renderer,
  }) async {
    final recording = (await _db.recordingsRepository.get(recordingId))
        .valueOrNull;
    final extraction = (await _db.extractionsRepository.get(extractionId))
        .valueOrNull;
    if (recording == null || extraction == null) {
      return const Err(StorageFailure('not found'));
    }
    final transcript = (await _db.transcriptsRepository.latestFor(recordingId))
        .valueOrNull;
    final segments = transcript == null
        ? const <TranscriptSegmentRow>[]
        : (await _db.transcriptsRepository.segments(transcript.id))
                  .valueOrNull ??
              const <TranscriptSegmentRow>[];
    try {
      return Ok(
        renderer(
          NoteInput(
            recording: recording,
            extraction: extraction.copyWith(json: edited, valid: true),
            segments: segments,
            speakerNames:
                (await _db.recordingsRepository.speakerNames(recordingId))
                    .valueOrNull ??
                const {},
          ),
        ),
      );
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  /// Stores [edited] as the extraction, marks exactly this content approved
  /// and moves the job on: a job in `waiting(review)` resumes (render →
  /// write); an already finished/failed job re-renders and re-exports so the
  /// note in the vault gets the edits. [valid] = the edits match the schema.
  Future<Result<void>> approveAndExport({
    required String extractionId,
    required Map<String, Object?> edited,
    required bool valid,
    required JobSnapshot? job,
  }) async {
    final saved = await _db.extractionsRepository.updateJson(
      extractionId,
      edited,
      valid: valid,
    );
    if (!saved.isOk) return saved;
    final approved = await _db.settingsRepository.set(
      ReviewKeys.approved(extractionId),
      extractionHash(edited),
    );
    if (!approved.isOk) return approved;
    if (job == null) return const Ok(null);
    try {
      final client = await _pipeline();
      return switch (job.state) {
        JobState.waiting => await client.resolveWaiting(job.id),
        JobState.done ||
        JobState.failed ||
        JobState.cancelled => await client.rerun(job.id, PipelineStepId.render),
        // Still running earlier steps: render picks the approval up later.
        _ => const Ok(null),
      };
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  /// Sets whether [profileId]'s results are reviewed before export.
  Future<Result<void>> setMode(String profileId, {required bool review}) =>
      _settings.set(ReviewKeys.mode(profileId), review);
}
