import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';

/// English notification strings (APP-06 moves these to ARB).
class EnglishProcessingNotificationTexts
    implements ProcessingNotificationTexts {
  const EnglishProcessingNotificationTexts();

  @override
  String get readyTitle => 'Your note is ready';

  @override
  String get readyBody => 'Tap to open it.';

  @override
  String readyTitleWithRecording(String recordingTitle) =>
      'Note ready — $recordingTitle';

  @override
  String get failedTitle => 'Processing needs attention';

  @override
  String get failedBody => 'Tap to see what happened.';

  @override
  String failedTitleWithRecording(String recordingTitle) =>
      'Processing failed — $recordingTitle';

  @override
  String get retryAction => 'Retry';
}

/// Status line for a job: the running step, or the resting state.
String jobStatusLabel(JobSnapshot job) => switch (job.state) {
  JobState.queued => 'Queued',
  JobState.transcribing => 'Transcribing',
  JobState.diarizing => 'Identifying speakers',
  JobState.classifying => 'Choosing a profile',
  JobState.extracting => 'Extracting details',
  JobState.rendering => 'Formatting the note',
  JobState.writing => 'Saving to your vault',
  JobState.transcribed ||
  JobState.extracted ||
  JobState.rendered => 'Waiting for the next step',
  JobState.done => 'Note ready',
  JobState.failed =>
    job.failureKind == FailureKind.permanent
        ? 'Processing failed'
        : 'Processing failed — you can retry',
  JobState.cancelled => 'Cancelled',
  JobState.paused => 'Paused',
  JobState.waiting => switch (job.waitingReason) {
    WaitingReason.modelMissing => 'Waiting for a model download',
    WaitingReason.profileChoice => 'Choose a profile to continue',
    WaitingReason.review => 'Ready for your review',
    WaitingReason.destination => 'Needs access to your vault folder',
    null => 'Waiting',
  },
};

/// "About 3 min left" style remaining time; `null` → estimating.
String etaLabel(Duration? eta) {
  if (eta == null) return 'Estimating time…';
  if (eta < const Duration(minutes: 1)) return 'Less than a minute left';
  final minutes = (eta.inSeconds / 60).round();
  if (minutes < 60) return 'About $minutes min left';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? 'About $h h left' : 'About $h h $m min left';
}
