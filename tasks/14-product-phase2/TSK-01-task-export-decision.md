# TSK-01 — Action-item export decision: Apple Reminders and Apple Notes

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** S | **Depends on:** SEC-02, SEC-06, SEC-08, APP-05, EXP-05 | **Source:** User decision 2026-10-17 (action items go to Apple Reminders or Apple Notes, the user's choice; Todoist dropped)
**Status:** todo
**Skills:** vv-task-workflow, vv-decision-records, vv-privacy-security, vv-markdown-vault-export, vv-licensing-iap

## Goal
Decide whether and how extracted action items may be pushed to Apple Reminders (EventKit, local) and Apple Notes (route to be verified) without weakening the "no user content leaves the device" promise.

## Scope
- [ ] State the privacy position: both destinations are on-device Apple apps; any iCloud sync is the user's own OS setting, outside our client. No third-party service and no new network host (Todoist was dropped by the user on 2026-10-17).
- [ ] Verify against official documentation (record versions and URLs): (a) EventKit reminder access on the iOS and macOS versions we target (access levels, Info.plist usage-description keys, macOS sandbox entitlement); (b) **the Apple Notes route**: Apple Notes has no EventKit equivalent, so determine what is officially possible on-device (system share sheet / "Add to Notes", App Intents or Shortcuts, anything else), whether notes can be created or appended, folder choice, checklist formatting, macOS support, and whether created note ids can be read back; (c) state what Android users get (no Apple apps). Anything not verifiable without a device becomes a device-row item.
- [ ] Choose the Notes mechanism from (b) and record limits honestly (for example a share-sheet route cannot report a note id, so re-export may create a duplicate note; define the user-facing behaviour). The destination (Reminders or Notes) is the user's choice per export.
- [ ] Define the shared domain model used by both exporters: which `action_items` rows are eligible (`done` false, with `body`; `owner` shown as text only; `due_iso` used as a due date only when present, never guessed from spoken text), the user-selects-items step (reuse the APP-05 review/selection UI), idempotency with a **stable export identity**: `action_items` rows are auto-increment and are deleted and re-inserted on re-render (`extractions_repository.dart`), so a mapping keyed by row id alone is not enough; define the identity (e.g. recording id + normalised body + `t`, or reconciliation on re-render) and what happens after review edits, re-render and re-extraction and failure handling (EXP-06 outbox semantics or none, decided).
- [ ] The ADR must confirm no new network host, permission beyond the Reminders usage description, or entitlement is needed; if the chosen Notes route needs one, it stops and asks for human approval with exact amendments to the privacy docs.
- [ ] Decide Free vs Pro placement as an explicit `PRODUCT-DECISION` for LIC-05; do not assume.
- [ ] Write `docs/adr/ADR-TSK-01-task-export.md` (Proposed) and update `docs/privacy-audit.md` and `docs/threat-model.md` drafts (final updates in SEC-11).

## Acceptance Criteria
- The ADR cites the official EventKit and Apple Notes documentation pages with the versions checked, and states for every claim whether it was verified or is a device-row item.
- The ADR names the Notes mechanism with its limits (create vs append, id read-back, duplicates on re-export) and the macOS position.
- The shared item model, eligibility rules and the stable idempotency identity (surviving re-render and re-extraction) are specified precisely enough to write tests from.
- The Android position (no Apple Reminders/Notes) and the macOS position are stated.
- `docs/privacy-audit.md` and `docs/threat-model.md` contain draft sections for the new data flows (artifact).

## Notes
- Google Tasks, Todoist, Asana, calendar events and email are out of scope.
- Todoist and other third-party services are out of scope by user decision; this task must not add any host to the allowlist.
