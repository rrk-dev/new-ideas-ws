# TSK-03 — Export action items to Apple Notes (user's choice alongside Reminders)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** TSK-01, TSK-02, LIC-05, APP-05 | **Source:** User decision 2026-10-17 (action items go to Apple Notes or Reminders, the user's choice; Todoist dropped)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-markdown-vault-export, vv-testing

## Goal
From the same selection UI as TSK-02, a user chooses a destination for selected action items: Apple Reminders or Apple Notes. Nothing leaves the device through our client.

## Scope
- [ ] Follow ADR-TSK-01 for the Notes mechanism. Apple Notes has no EventKit equivalent; TSK-01 must verify against official documentation which on-device route exists (for example the system share sheet / "Add to Notes", or an App Intent / Shortcut), what it can and cannot do (create vs append, folder choice, checklist formatting, macOS support) and record the result. Do not assume a direct-write API exists.
- [ ] Notes exporter producing a plain-text or checklist-style note from the selected items (title = recording title and date; one line per item; owner and `due_iso` as text only). No transcript text beyond what the user selected.
- [ ] Destination chooser in the export UI (Reminders / Notes), remembering the last choice; the shared item model and eligibility rules from TSK-01 apply to both.
- [ ] Idempotency per TSK-01: if the chosen route cannot report a created note id, the UI states that re-export creates a new note and asks for confirmation rather than silently duplicating.
- [ ] Android: Notes and Reminders are Apple-only; the action is hidden (or offers the plain system share, if TSK-01 decides so).
- [ ] No new permission, entitlement or network host; if the route needs one, stop and amend ADR-TSK-01 for approval.
- [ ] Tests: Dart unit tests with a fake export channel; widget tests; device rows for the real Notes behaviour on iPhone and macOS.

## Acceptance Criteria
- With a fake channel: selected eligible items produce one note whose text matches the golden; ineligible items are skipped (`[TSK-03/AC1]`).
- The destination choice routes to the right exporter and is remembered (`[TSK-03/AC2]`).
- Re-export behaviour matches the ADR (warning or dedupe) (`[TSK-03/AC3]`).
- On a physical iPhone and macOS the exported note appears in Apple Notes with the expected text (device rows `docs/test-plans/device/TSK-03.md`, ⏳ until run).
- `check_egress.sh` is unchanged and passes; no item text appears in logs (log-content test).
- Android shows no Apple export action (widget test).

## Notes
- Google Tasks, Todoist and other third-party services are out of scope by user decision (2026-10-17).
