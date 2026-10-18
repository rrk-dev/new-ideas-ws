// Pigeon definition for the Apple Reminders (EventKit) host API (TSK-02,
// ADR-TSK-01). iOS and macOS share one Swift implementation
// (`ios/Runner/RemindersHostApiImpl.swift`, referenced from the macOS
// project); Android has no host: Dart answers "unsupported" and hides the
// action.
// Regenerate after editing (from app/):
//   fvm dart run pigeon --input pigeons/reminders_api.dart
//   fvm dart format lib/features/reminders/data/pigeon/reminders_api.g.dart
//
// Verified against pigeon 29.0.8.
//
// Content rule: reminder titles and notes cross this boundary only as data
// for EventKit, are never logged, and are never put into a URL or command.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/reminders/data/pigeon/reminders_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/RemindersApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'RemindersPigeonError'),
    dartPackageName: 'vaultvoice',
  ),
)
/// EventKit authorization for reminders. `unsupported` is for builds without
/// the EventKit host (the Dart side also uses it for Android).
enum ReminderAuthStatusMessage {
  notDetermined,
  denied,
  restricted,
  granted,
  unsupported,
}

/// A Reminders list the app may write to.
class ReminderListMessage {
  ReminderListMessage({required this.id, required this.title});

  /// `EKCalendar.calendarIdentifier`.
  String id;
  String title;
}

/// One reminder to create. Due components are set only when the extraction
/// had a parseable `due_iso`; hour and minute only for a date-time.
class ReminderDraftMessage {
  ReminderDraftMessage({
    required this.key,
    required this.title,
    this.notes,
    this.dueYear,
    this.dueMonth,
    this.dueDay,
    this.dueHour,
    this.dueMinute,
  });

  /// Idempotency key echoed back in the result; never shown or stored by
  /// native code.
  String key;
  String title;
  String? notes;
  int? dueYear;
  int? dueMonth;
  int? dueDay;
  int? dueHour;
  int? dueMinute;
}

/// Outcome for one draft.
class ReminderCreatedMessage {
  ReminderCreatedMessage({
    required this.key,
    required this.ok,
    this.calendarItemId,
  });

  String key;
  bool ok;

  /// `EKCalendarItem.calendarItemIdentifier` of the saved reminder.
  String? calendarItemId;
}

/// Result of one batch: where the reminders went and per-item outcomes.
class ReminderBatchMessage {
  ReminderBatchMessage({
    required this.listId,
    required this.listTitle,
    required this.fellBackToDefault,
    required this.created,
  });

  String listId;
  String listTitle;

  /// The dedicated "Lumen" list could not be created or found, so the
  /// default Reminders list was used.
  bool fellBackToDefault;
  List<ReminderCreatedMessage> created;
}

@HostApi()
abstract class RemindersHostApi {
  /// Current status without prompting.
  ReminderAuthStatusMessage authorizationStatus();

  /// Prompts (first time only) for full reminders access (ADR-TSK-01 E1/E2).
  @async
  ReminderAuthStatusMessage requestAccess();

  /// Writable Reminders lists (`allowsContentModifications`).
  @async
  List<ReminderListMessage> writableLists();

  /// Creates [drafts] in the list [listId]; a null or no longer existing id
  /// means the dedicated "Lumen" list (created when missing, else the
  /// default list). Saves in one batch and commits once. Throws
  /// `PlatformException` code `denied` when access is missing.
  @async
  ReminderBatchMessage createReminders(
    String? listId,
    List<ReminderDraftMessage> drafts,
  );

  /// Subset of [calendarItemIds] that still resolve to a reminder
  /// (`calendarItem(withIdentifier:)`). Never reads other reminders.
  @async
  List<String> existingReminderIds(List<String> calendarItemIds);
}
