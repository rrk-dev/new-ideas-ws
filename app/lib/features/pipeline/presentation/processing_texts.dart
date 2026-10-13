import 'package:vaultvoice/core/l10n/l10n.dart';
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
String jobStatusLabel(AppLocalizations l, JobSnapshot job) =>
    switch (job.state) {
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
        WaitingReason.modelMissing => l.jobWaitingModel,
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
