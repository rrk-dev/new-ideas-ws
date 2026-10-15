import 'package:drift/drift.dart' show Value;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/domain/classification_keys.dart';
import 'package:vaultvoice/features/profiles/domain/profile_classifier.dart';

/// "Auto" profile selection (PRF-06): runs only for recordings without a
/// chosen profile (`recordings.profile_id` null), between transcription and
/// extraction.
///
/// A confident answer stores the profile on the recording, so extraction,
/// template and routing follow it. Below the classifier's threshold the job
/// parks in `waiting(profileChoice)` with the suggestion stored under
/// [ClassificationKeys.result]; the user picks a profile (recording detail →
/// change profile = re-run from extract) or resumes the job to accept the
/// suggestion. Without a profile list (tests, FND-05 defaults) the step does
/// nothing and extraction uses `PipelineConfig.defaultProfileId`.
class ClassifyStep implements PipelineStep {
  ClassifyStep({
    required this.db,
    required this.llm,
    required this.config,
    this.activeModel,
    this.profileList,
    ProfileClassifier? classifier,
  }) : classifier = classifier ?? ProfileClassifier(llm: llm);

  final VaultVoiceDatabase db;
  final LlmEngine llm;
  final PipelineConfig config;
  final ActiveModelIdLookup? activeModel;
  final ProfileListLookup? profileList;
  final ProfileClassifier classifier;

  @override
  PipelineStepId get id => PipelineStepId.classify;

  @override
  HeavyModel get model => HeavyModel.llm;

  @override
  bool canRun(JobSnapshot job) => profileList != null;

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final recording = unwrap(
      await db.recordingsRepository.get(job.recordingId),
    );
    if (recording.profileId != null) return const StepSucceeded();
    final candidates = await profileList!();
    if (candidates.isEmpty) return const StepSucceeded();

    final transcript = unwrap(
      await db.transcriptsRepository.latestFor(job.recordingId),
    );
    if (transcript == null) {
      return const StepFailed(
        StorageFailure('no transcript'),
        kind: FailureKind.permanent,
      );
    }
    final segments = unwrap(
      await db.transcriptsRepository.segments(transcript.id),
    );
    final text = segments.map((s) => s.body).join(' ');

    var llmAvailable = true;
    if (activeModel case final lookup?) {
      llmAvailable = await lookup(HeavyModel.llm) != null;
    }
    // Keywords can decide without a model; otherwise wait for one.
    final result = await classifier.classify(
      candidates,
      text,
      cancel: ctx.cancel,
      allowLlm: llmAvailable,
    );
    if (result case Err(:final failure)) {
      if (!llmAvailable) return const StepWaiting(WaitingReason.modelMissing);
      return StepFailed(failure);
    }
    final c = result.valueOrNull!;

    // Asked once: resuming the waiting job accepts the suggestion.
    final asked = job.checkpoint['asked'] == true;
    final ask = c.needsChoice && !asked;
    Future<void> store() async {
      unwrap(
        await db.settingsRepository.set(
          ClassificationKeys.result(job.recordingId),
          {
            'profile': c.profileId,
            'confidence': c.confidence,
            'method': c.method.name,
            'asked': ask || asked,
          },
        ),
      );
    }

    if (ask) {
      await ctx.saveCheckpoint(const {'asked': true}, writes: store);
      return const StepWaiting(WaitingReason.profileChoice);
    }
    return StepSucceeded(
      commit: () async {
        await store();
        unwrap(
          await db.recordingsRepository.updateFields(
            job.recordingId,
            RecordingsCompanion(profileId: Value(c.profileId)),
          ),
        );
      },
    );
  }
}
