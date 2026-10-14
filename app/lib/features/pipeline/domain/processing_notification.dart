import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// What a processing notification announces.
enum ProcessingNotificationKind { noteReady, failed }

/// Notification action ids (payload of the tap callback).
abstract final class NotificationActions {
  /// "Retry" on a failure notification.
  static const retry = 'retry';
}

/// A local notification about a job (APP-04). Content-free unless the user
/// opted into details: by default the text is generic so nothing about the
/// recording shows on the lock screen.
class ProcessingNotification {
  const ProcessingNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.payload,
    required this.revealsContent,
    this.actions = const [],
  });

  /// Stable per job, so a newer state replaces the older notification.
  final int id;
  final ProcessingNotificationKind kind;
  final String title;
  final String body;

  /// Typed-route location opened on tap (e.g. `/library/recordings/<id>`).
  final String payload;

  /// Whether [title]/[body] contain user content (the recording title);
  /// such notifications are marked private for the lock screen.
  final bool revealsContent;

  /// `(actionId, label)` pairs, e.g. `(NotificationActions.retry, 'Retry')`.
  final List<(String, String)> actions;

  @override
  String toString() =>
      'ProcessingNotification($id, ${kind.name}, '
      'revealsContent: $revealsContent)';
}

/// User-facing notification strings (localised by the caller — APP-06).
abstract interface class ProcessingNotificationTexts {
  String get readyTitle;
  String get readyBody;
  String readyTitleWithRecording(String recordingTitle);
  String get failedTitle;
  String get failedBody;
  String failedTitleWithRecording(String recordingTitle);
  String get retryAction;
}

/// Stable positive 31-bit notification id for [jobId] (FNV-1a).
int notificationIdFor(String jobId) {
  var hash = 0x811c9dc5;
  for (final unit in jobId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// The notification for a job's transition [previous] → `job.state`, or
/// `null` if the transition is not announced. Only *entering* `done` or
/// `failed` is announced (automatic retries go back to a resting state and
/// stay silent until the last attempt fails). [previous] `null` means the
/// job was first seen in this state (e.g. after a restart): not announced.
///
/// [showDetails] is the user's lock-screen privacy setting (default off):
/// only then is the recording title included.
ProcessingNotification? composeProcessingNotification({
  required JobState? previous,
  required JobSnapshot job,
  required String? recordingTitle,
  required bool showDetails,
  required ProcessingNotificationTexts texts,
  required String payload,
}) {
  if (previous == null || previous == job.state) return null;
  final title = recordingTitle?.trim() ?? '';
  final detailed = showDetails && title.isNotEmpty;
  return switch (job.state) {
    JobState.done => ProcessingNotification(
      id: notificationIdFor(job.id),
      kind: ProcessingNotificationKind.noteReady,
      title: detailed ? texts.readyTitleWithRecording(title) : texts.readyTitle,
      body: texts.readyBody,
      payload: payload,
      revealsContent: detailed,
    ),
    JobState.failed => ProcessingNotification(
      id: notificationIdFor(job.id),
      kind: ProcessingNotificationKind.failed,
      title: detailed
          ? texts.failedTitleWithRecording(title)
          : texts.failedTitle,
      body: texts.failedBody,
      payload: payload,
      revealsContent: detailed,
      actions: [(NotificationActions.retry, texts.retryAction)],
    ),
    _ => null,
  };
}
