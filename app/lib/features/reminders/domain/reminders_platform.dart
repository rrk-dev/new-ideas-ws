import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/reminders/domain/reminder_item.dart';

/// Access to the user's reminders (EventKit).
enum ReminderAccess {
  notDetermined,
  denied,
  restricted,
  granted,

  /// No Reminders on this platform (Android) or no host in this build.
  unsupported;

  bool get blocked => this == denied || this == restricted;
}

/// A Reminders list the app may write to.
@immutable
final class ReminderList {
  const ReminderList({required this.id, required this.title});

  final String id;

  /// User content: displayed, never logged.
  final String title;
}

/// Outcome for one draft.
@immutable
final class ReminderCreated {
  const ReminderCreated({
    required this.key,
    required this.ok,
    this.calendarItemId,
  });

  final String key;
  final bool ok;
  final String? calendarItemId;
}

/// Where a batch went and what happened to each item.
@immutable
final class ReminderBatch {
  const ReminderBatch({
    required this.listId,
    required this.listTitle,
    required this.fellBackToDefault,
    required this.created,
  });

  final String listId;
  final String listTitle;
  final bool fellBackToDefault;
  final List<ReminderCreated> created;
}

/// Reminders access was refused or revoked.
class RemindersAccessDenied implements Exception {
  const RemindersAccessDenied();

  @override
  String toString() => 'RemindersAccessDenied';
}

/// The EventKit host failed (content-free).
class RemindersPlatformError implements Exception {
  const RemindersPlatformError(this.code);

  final String code;

  @override
  String toString() => 'RemindersPlatformError($code)';
}

/// EventKit seen from Dart (ADR-TSK-01). The Pigeon-backed implementation is
/// `PigeonRemindersPlatform`; tests use `FakeRemindersPlatform`.
abstract interface class RemindersPlatform {
  Future<ReminderAccess> authorizationStatus();

  /// Prompts only while the status is [ReminderAccess.notDetermined].
  Future<ReminderAccess> requestAccess();

  /// Throws [RemindersAccessDenied] without access.
  Future<List<ReminderList>> writableLists();

  /// Creates [drafts] in [listId]; null or a deleted list means the
  /// dedicated "Lumen" list, then the default list. Throws
  /// [RemindersAccessDenied] without access.
  Future<ReminderBatch> createReminders({
    required String? listId,
    required List<ReminderDraft> drafts,
  });

  /// The subset of [calendarItemIds] that still exist as reminders.
  Future<Set<String>> existingReminderIds(Iterable<String> calendarItemIds);
}
