import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/presentation/model_texts.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';

/// Notification strings from the app's ARB (`app_en.arb`).
class L10nProcessingNotificationTexts implements ProcessingNotificationTexts {
  const L10nProcessingNotificationTexts(this.l10n);

  final AppLocalizations l10n;

  @override
  String get readyTitle => l10n.notificationReadyTitle;

  @override
  String get readyBody => l10n.notificationReadyBody;

  @override
  String readyTitleWithRecording(String recordingTitle) =>
      l10n.notificationReadyTitleWithRecording(recordingTitle);

  @override
  String get failedTitle => l10n.notificationFailedTitle;

  @override
  String get failedBody => l10n.notificationFailedBody;

  @override
  String failedTitleWithRecording(String recordingTitle) =>
      l10n.notificationFailedTitleWithRecording(recordingTitle);

  @override
  String get retryAction => l10n.commonRetry;
}

/// English notification strings (tests and non-UI callers).
class EnglishProcessingNotificationTexts
    extends L10nProcessingNotificationTexts {
  EnglishProcessingNotificationTexts() : super(l10nFor(kFallbackLocale));
}

/// Status line for a job: the running step, or the resting state.
///
/// A job waiting for a model names the missing model type and, when known,
/// the model ([missingModel]).
String jobStatusLabel(
  AppLocalizations l,
  JobSnapshot job, {
  MissingModel? missingModel,
}) => switch (job.state) {
  JobState.queued => l.jobQueued,
  JobState.transcribing => l.jobTranscribing,
  JobState.diarizing => l.jobDiarizing,
  JobState.classifying => l.jobClassifying,
  JobState.extracting => l.jobExtracting,
  JobState.rendering => l.jobRendering,
  JobState.writing => l.jobWriting,
  JobState.transcribed ||
  JobState.extracted ||
  JobState.rendered => l.jobBetweenSteps,
  JobState.done => l.jobDone,
  JobState.failed =>
    job.failureKind == FailureKind.permanent
        ? l.jobFailedPermanent
        : l.jobFailedRetryable,
  JobState.cancelled => l.jobCancelled,
  JobState.paused => l.jobPaused,
  JobState.waiting => switch (job.waitingReason) {
    WaitingReason.modelMissing => missingModelLabel(
      l,
      missingModel ?? MissingModel(type: modelTypeForStep(job.step)),
    ),
    WaitingReason.profileChoice => l.jobWaitingProfile,
    WaitingReason.review => l.jobWaitingReview,
    WaitingReason.destination => l.jobWaitingDestination,
    null => l.jobWaiting,
  },
};

/// "About 3 min left" style remaining time; `null` → estimating.
String etaLabel(AppLocalizations l, Duration? eta) {
  if (eta == null) return l.etaEstimating;
  if (eta < const Duration(minutes: 1)) return l.etaUnderMinute;
  final minutes = (eta.inSeconds / 60).round();
  if (minutes < 60) return l.etaMinutes(minutes);
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? l.etaHours(h) : l.etaHoursMinutes(h, m);
}

/// The kind of model a pipeline step needs: speech-to-text for
/// transcription, the language model for classification and extraction.
ModelType modelTypeForStep(PipelineStepId step) => switch (step) {
  PipelineStepId.transcribe => ModelType.stt,
  _ => ModelType.llm,
};

/// A model a waiting job needs (see [jobStatusLabel]).
class MissingModel {
  const MissingModel({required this.type, this.name, this.installedName});

  final ModelType type;

  /// Recommended model to download, when the catalog is available.
  final String? name;

  /// An installed model of this [type] that could be used instead.
  final String? installedName;
}

String missingModelLabel(AppLocalizations l, MissingModel m) {
  final type = ModelTexts.type(l, m.type);
  final name = m.name ?? m.installedName;
  return name == null
      ? l.jobWaitingModelType(type)
      : l.jobWaitingModelNamed(type, name);
}
