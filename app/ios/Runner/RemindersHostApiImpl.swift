import EventKit
import Foundation

/// Apple Reminders host API shared by iOS and macOS (TSK-02, ADR-TSK-01).
///
/// - Permission: full reminders access, requested only when Dart asks after
///   the user's tap (`requestFullAccessToReminders`, iOS 17 / macOS 14; the
///   deprecated `requestAccess(to: .reminder)` before that). There is no
///   write-only level for reminders (ADR E2).
/// - Create-only: reminders are saved in one batch and committed once. The
///   only reads are the lists the user may write to and the reminders whose
///   identifiers Dart stored (`calendarItem(withIdentifier:)`).
/// - No network code: EventKit talks to the local Reminders store; sync is
///   the user's own account setting.
/// - Content (titles, notes) is data for EventKit only and is never logged.
///
/// Written against the developer.apple.com EventKit reference read on
/// 2026-10-18 (EKEventStore, EKCalendar, EKReminder, EKAuthorizationStatus)
/// and the Pigeon 29.0.8 `RemindersHostApi` protocol.
final class RemindersHostApiImpl: RemindersHostApi {
  private static let listTitle = "Lumen"

  private static func err(_ code: String, _ message: String) -> RemindersPigeonError {
    RemindersPigeonError(code: code, message: message, details: nil)
  }

  private func status() -> ReminderAuthStatusMessage {
    switch EKEventStore.authorizationStatus(for: .reminder) {
    case .notDetermined:
      return .notDetermined
    case .restricted:
      return .restricted
    case .denied:
      return .denied
    case .writeOnly:
      // Not offered for reminders; treated as no usable access.
      return .denied
    default:
      // `.fullAccess` (iOS 17 / macOS 14) and the deprecated `.authorized`.
      return .granted
    }
  }

  func authorizationStatus() throws -> ReminderAuthStatusMessage {
    status()
  }

  func requestAccess() async throws -> ReminderAuthStatusMessage {
    let current = status()
    if current != .notDetermined { return current }
    let store = EKEventStore()
    do {
      if #available(iOS 17.0, macOS 14.0, *) {
        _ = try await store.requestFullAccessToReminders()
      } else {
        _ = try await withCheckedThrowingContinuation {
          (c: CheckedContinuation<Bool, Error>) in
          store.requestAccess(to: .reminder) { granted, error in
            if let error = error {
              c.resume(throwing: error)
            } else {
              c.resume(returning: granted)
            }
          }
        }
      }
    } catch {
      // The status below tells Dart what happened.
    }
    return status()
  }

  func writableLists() async throws -> [ReminderListMessage] {
    guard status() == .granted else { throw Self.err("denied", "reminders access missing") }
    let store = EKEventStore()
    return store.calendars(for: .reminder)
      .filter { $0.allowsContentModifications }
      .map { ReminderListMessage(id: $0.calendarIdentifier, title: $0.title) }
  }

  func createReminders(listId: String?, drafts: [ReminderDraftMessage]) async throws
    -> ReminderBatchMessage
  {
    guard status() == .granted else { throw Self.err("denied", "reminders access missing") }
    let store = EKEventStore()
    var fellBack = false
    let calendar: EKCalendar
    if let id = listId, let chosen = store.calendar(withIdentifier: id),
      chosen.allowsContentModifications
    {
      calendar = chosen
    } else {
      let resolved = try Self.dedicatedList(store)
      calendar = resolved.calendar
      fellBack = resolved.fellBack
    }

    var results: [ReminderCreatedMessage] = []
    var saved: [(key: String, reminder: EKReminder)] = []
    for draft in drafts {
      let reminder = EKReminder(eventStore: store)
      reminder.calendar = calendar
      reminder.title = draft.title
      reminder.notes = draft.notes
      if let year = draft.dueYear, let month = draft.dueMonth, let day = draft.dueDay {
        var due = DateComponents()
        due.year = Int(year)
        due.month = Int(month)
        due.day = Int(day)
        if let hour = draft.dueHour, let minute = draft.dueMinute {
          due.hour = Int(hour)
          due.minute = Int(minute)
        }
        reminder.dueDateComponents = due
      }
      do {
        try store.save(reminder, commit: false)
        saved.append((draft.key, reminder))
      } catch {
        results.append(ReminderCreatedMessage(key: draft.key, ok: false, calendarItemId: nil))
      }
    }
    do {
      try store.commit()
      for item in saved {
        results.append(
          ReminderCreatedMessage(
            key: item.key, ok: true, calendarItemId: item.reminder.calendarItemIdentifier))
      }
    } catch {
      store.reset()
      for item in saved {
        results.append(ReminderCreatedMessage(key: item.key, ok: false, calendarItemId: nil))
      }
    }
    return ReminderBatchMessage(
      listId: calendar.calendarIdentifier, listTitle: calendar.title,
      fellBackToDefault: fellBack, created: results)
  }

  func existingReminderIds(calendarItemIds: [String]) async throws -> [String] {
    guard status() == .granted else { return [] }
    let store = EKEventStore()
    return calendarItemIds.filter { store.calendarItem(withIdentifier: $0) is EKReminder }
  }

  /// The "Lumen" list: an existing writable one by title, else a new one on
  /// the default list's source; when that fails, the default list.
  private static func dedicatedList(_ store: EKEventStore) throws -> (
    calendar: EKCalendar, fellBack: Bool
  ) {
    if let existing = store.calendars(for: .reminder).first(where: {
      $0.title == listTitle && $0.allowsContentModifications
    }) {
      return (existing, false)
    }
    let fallback = store.defaultCalendarForNewReminders()
    let created = EKCalendar(for: .reminder, eventStore: store)
    created.title = listTitle
    if let source = fallback?.source
      ?? store.sources.first(where: { $0.sourceType == .local })
    {
      created.source = source
      do {
        try store.saveCalendar(created, commit: true)
        return (created, false)
      } catch {
        store.reset()
      }
    }
    guard let fallback = store.defaultCalendarForNewReminders() else {
      throw err("unavailable", "no writable reminders list")
    }
    return (fallback, true)
  }
}
