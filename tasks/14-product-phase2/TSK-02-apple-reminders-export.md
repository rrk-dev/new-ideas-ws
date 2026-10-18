# TSK-02 — Export action items to Apple Reminders (iOS and macOS)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** TSK-01, LIC-05, APP-02, APP-05, AUD-09 | **Source:** User decision 2026-10-16 (product Phase 2: Reminders export; Reminders is local)
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-ffi-bridge, vv-privacy-security, vv-licensing-iap, vv-testing

## Goal
From a recording's action items (or the library-wide Action Items screen), a user can select items and create reminders in Apple Reminders, once per item, with the due date when one was extracted.

## Scope
- [x] Platform channel (Pigeon) for EventKit on iOS and macOS following ADR-TSK-01: request the access level the ADR chose, list writable reminder lists, create/update a reminder, read back only the identifiers this app created. Android returns "unsupported" and the UI hides the action.
- [x] Info.plist usage-description keys and, on macOS, the sandbox entitlement named in the ADR; no other new permission, entitlement or network host. Update `docs/privacy-audit.md` data-flow notes (Reminders is on-device).
- [x] Domain exporter implementing the shared item model from the ADR: eligibility, selection, due date only from `due_iso`, notes field with a back-reference (recording title and timestamp) and no transcript text beyond what the user selected, idempotency table (drift migration) mapping action item → external reminder id; re-push updates or skips.
- [x] UI: "Add to Reminders" in the recording detail and on the Action Items screen: list picker (remember last list), per-item checkboxes, result summary (created / skipped / failed), permission-denied state with a link to system settings, and macOS parity.
- [x] Failure handling per the ADR (no crash if Reminders access is revoked or a list is deleted).
- [x] Gating through `FeatureGate` per LIC-05 (no new gating logic).
- [x] Tests: Dart unit tests with a fake channel; widget tests; migration test; device rows for the EventKit behaviour.

## Acceptance Criteria
- With a fake EventKit channel: eligible items are created once, ineligible (done, empty) are skipped, a second push does not duplicate, a deleted external reminder is handled without error (`[TSK-02/AC1]`).
- Due dates are set only when `due_iso` exists; an item with only a spoken due phrase creates a reminder without a due date (`[TSK-02/AC2]`).
- Denied or revoked permission shows the recovery state and creates nothing (widget test `[TSK-02/AC3]`).
- On a physical iPhone and on macOS, selected items appear in the chosen Reminders list with the expected title, due date and note (device rows `docs/test-plans/device/TSK-02.md`, ⏳ until run, `[TSK-02/AC4]`).
- Android shows no Reminders action (widget test); `check_egress.sh` is unchanged and passes; no reminder text appears in logs (log-content test) (`[TSK-02/AC5]`).
- Push → re-render → push does not create a duplicate reminder (`[TSK-02/AC6]`).
- Deleting a recording removes its idempotency rows (DB test) (`[TSK-02/AC7]`).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/TSK-02-apple-reminders-export · **Date:** 2026-10-18
- **Summary:** Pigeon `RemindersHostApi` with one Swift EventKit implementation (`app/ios/Runner/RemindersHostApiImpl.swift`) shared by the iOS and macOS Runner targets. It uses a fresh `EKEventStore` per call, full-access request (`requestFullAccessToReminders` on iOS 17 / macOS 14, `requestAccess(to:)` before), a dedicated "Lumen" list with fallback to the default list, and a single `commit`. Dart side: `reminders_exporter.dart` (candidates with `available / added / addedMissing`, re-checks links at export time, create-only), drift schema v5 table `reminder_exports` (key = sha256(recordingId, normalised body, occurrence), cascade with the recording, also removed by the transcript purge scope), bottom sheet `reminders_sheet.dart` (primer, recovery state, list picker with last list remembered, per-item checkboxes, result summary) reachable from the recording menu and the Action Items app bar, gated by `ensureFeature(Feature.remindersExport)` (open while `proTierEnforced` is false). Android uses `UnsupportedRemindersPlatform` and shows no action.
- **Deviations:** (1) Notes are `Owner: <owner>` and `From Lumen, <date>`: ADR-TSK-01 excludes the recording title, which overrides the task text. (2) Create-only: no update of an existing reminder (ADR); a changed wording is a new item. (3) The review screen is not an entry point; recording detail and Action Items are. (4) Items with a link row that are done are shown only when already added.
- **Unverified (device rows in docs/test-plans/device/TSK-02.md):** the iOS 17 prompt (D1), the iOS 16 / macOS 13 path (D2), the macOS entitlement `com.apple.security.personal-information.calendars` covering Reminders (D3, **release gate**), list creation on iCloud / local sources (D8), identifier stability after sync/reinstall (D7), no network from our process (D10). Both Runners compile (`flutter build macos` and `flutter build ios --no-codesign`, dev flavor), but no EventKit call has run.
- **Acceptance evidence:**
  - AC1: ✅ test: [TSK-02/AC1]; ci: nice -n 10 fvm flutter test test/unit/reminders/reminders_exporter_test.dart
  - AC2: ✅ test: [TSK-02/AC2]; ci: nice -n 10 fvm flutter test test/unit/reminders/reminders_exporter_test.dart
  - AC3: ✅ test: [TSK-02/AC3]; ci: nice -n 10 fvm flutter test test/widget/reminders_sheet_test.dart
  - AC4: ⏳ device: docs/test-plans/device/TSK-02.md (rows D1–D11); artifact test [TSK-02/AC4]
  - AC5: ✅ test: [TSK-02/AC5]; ci: nice -n 10 fvm flutter test test/widget/reminders_sheet_test.dart test/unit/reminders/reminders_exporter_test.dart; bash tools/ci/check_egress.sh (unchanged)
  - AC6: ✅ test: [TSK-02/AC6]; ci: nice -n 10 fvm flutter test test/unit/reminders/reminders_exporter_test.dart
  - AC7: ✅ test: [TSK-02/AC7]; ci: nice -n 10 fvm flutter test test/unit/reminders/reminders_exporter_test.dart test/db/migrations/vaultvoice/migration_test.dart
- **Follow-ups:** no Swift unit tests for `RemindersHostApiImpl` (EventKit needs a device); reminder link rows are lost on reinstall (documented, D7).
