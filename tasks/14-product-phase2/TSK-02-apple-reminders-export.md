# TSK-02 — Export action items to Apple Reminders (iOS and macOS)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** TSK-01, APP-02, APP-05, AUD-09 | **Source:** User decision 2026-10-16 (product Phase 2: Reminders export; Reminders is local)
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-ffi-bridge, vv-privacy-security, vv-licensing-iap, vv-testing

## Goal
From a recording's action items (or the library-wide Action Items screen), a user can select items and create reminders in Apple Reminders, once per item, with the due date when one was extracted.

## Scope
- [ ] Platform channel (Pigeon) for EventKit on iOS and macOS following ADR-TSK-01: request the access level the ADR chose, list writable reminder lists, create/update a reminder, read back only the identifiers this app created. Android returns "unsupported" and the UI hides the action.
- [ ] Info.plist usage-description keys and, on macOS, the sandbox entitlement named in the ADR; no other new permission, entitlement or network host. Update `docs/privacy-audit.md` data-flow notes (Reminders is on-device).
- [ ] Domain exporter implementing the shared item model from the ADR: eligibility, selection, due date only from `due_iso`, notes field with a back-reference (recording title and timestamp) and no transcript text beyond what the user selected, idempotency table (drift migration) mapping action item → external reminder id; re-push updates or skips.
- [ ] UI: "Add to Reminders" in the recording detail and on the Action Items screen: list picker (remember last list), per-item checkboxes, result summary (created / skipped / failed), permission-denied state with a link to system settings, and macOS parity.
- [ ] Failure handling per the ADR (no crash if Reminders access is revoked or a list is deleted).
- [ ] Gating through `FeatureGate` per LIC-05 (no new gating logic).
- [ ] Tests: Dart unit tests with a fake channel; widget tests; migration test; device rows for the EventKit behaviour.

## Acceptance Criteria
- With a fake EventKit channel: eligible items are created once, ineligible (done, empty) are skipped, a second push does not duplicate, a deleted external reminder is handled without error (`[TSK-02/AC1]`).
- Due dates are set only when `due_iso` exists; an item with only a spoken due phrase creates a reminder without a due date (`[TSK-02/AC2]`).
- Denied or revoked permission shows the recovery state and creates nothing (widget test `[TSK-02/AC3]`).
- On a physical iPhone and on macOS, selected items appear in the chosen Reminders list with the expected title, due date and note (device rows `docs/test-plans/device/TSK-02.md`, ⏳ until run).
- Android shows no Reminders action (widget test); `check_egress.sh` is unchanged and passes; no reminder text appears in logs (log-content test).
- Deleting a recording removes its idempotency rows (DB test).
