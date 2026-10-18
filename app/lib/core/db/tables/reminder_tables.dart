// Declarative drift DSL: never executed at runtime (drift_dev generates the
// table code in database.g.dart), so it is excluded from line coverage.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/tables/recording_tables.dart';

/// Link from an action item to the Apple Reminders item created for it
/// (TSK-02, ADR-TSK-01 §6). `itemKey` is `sha256(recordingId, normalised
/// body, occurrence)`, so it survives a re-render that replaces the
/// `action_items` rows. No item text is stored. Deleting the recording
/// removes the link; the reminder itself is never deleted by the app.
@DataClassName('ReminderExportRow')
class ReminderExports extends Table {
  TextColumn get itemKey => text()();
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();

  /// `EKCalendarItem.calendarItemIdentifier`.
  TextColumn get calendarItemId => text()();

  /// `EKCalendar.calendarIdentifier` of the list it went to.
  TextColumn get reminderCalendarId => text()();
  IntColumn get exportedAt => integer().map(const EpochMsConverter())();

  @override
  Set<Column> get primaryKey => {itemKey};
}
