# TSK-01 — Action-item export decision: Apple Reminders

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** S | **Depends on:** SEC-02, SEC-06, SEC-08, APP-05, EXP-05 | **Source:** User decision 2026-10-17 (action items go to Apple Reminders only; Todoist and Apple Notes dropped)
**Status:** review
**Skills:** vv-task-workflow, vv-decision-records, vv-privacy-security, vv-markdown-vault-export, vv-licensing-iap

## Goal
Decide whether and how extracted action items may be pushed to Apple Reminders (EventKit, local) without weakening the "no user content leaves the device" promise.

## Scope
- [x] State the privacy position: the destination is the on-device Apple Reminders app; any iCloud sync is the user's own OS setting, outside our client. No third-party service and no new network host (Todoist and Apple Notes were dropped by the user on 2026-10-17).
- [x] Verify against official documentation (record versions and URLs): (a) EventKit reminder access on the iOS and macOS versions we target (access levels, Info.plist usage-description keys, macOS sandbox entitlement); (b) state what Android users get (no Apple apps). Anything not verifiable without a device becomes a device-row item.
- [x] Define the shared domain model used by both exporters: which `action_items` rows are eligible (`done` false, with `body`; `owner` shown as text only; `due_iso` used as a due date only when present, never guessed from spoken text), the user-selects-items step (reuse the APP-05 review/selection UI), idempotency with a **stable export identity**: `action_items` rows are auto-increment and are deleted and re-inserted on re-render (`extractions_repository.dart`), so a mapping keyed by row id alone is not enough; define the identity (e.g. recording id + normalised body + `t`, or reconciliation on re-render) and what happens after review edits, re-render and re-extraction and failure handling (EXP-06 outbox semantics or none, decided).
- [x] The ADR must confirm no new network host, permission beyond the Reminders usage description, or entitlement is needed; if one is needed, it stops and asks for human approval with exact amendments to the privacy docs.
- [x] Decide Free vs Pro placement as an explicit `PRODUCT-DECISION` for LIC-05; do not assume.
- [x] Write `docs/adr/ADR-TSK-01-task-export.md` (Proposed) and update `docs/privacy-audit.md` and `docs/threat-model.md` drafts (final updates in SEC-11).

## Acceptance Criteria
- The ADR cites the official EventKit and EventKit documentation pages with the versions checked, and states for every claim whether it was verified or is a device-row item.
- The ADR states whether Reminders items can be read back by id for idempotency and the macOS position.
- The shared item model, eligibility rules and the stable idempotency identity (surviving re-render and re-extraction) are specified precisely enough to write tests from.
- The Android position (no Apple Reminders) and the macOS position are stated.
- `docs/privacy-audit.md` and `docs/threat-model.md` contain draft sections for the new data flows (artifact).

## Notes
- Google Tasks, Todoist, Apple Notes (no public write API per user decision), Asana, calendar events and email are out of scope.
- Todoist, Apple Notes and other third-party services are out of scope by user decision; this task must not add any host to the allowlist.

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** task/TSK-01-reminders-decision · **Date:** 2026-10-17
- **Summary:** Decision written as ADR-TSK-01 (Proposed): Apple Reminders via our own EventKit Pigeon plugin, explicit user selection only, no network host, no outbox, create-only with a stable export identity `sha256(recordingId, norm(body), occurrence)` stored in a future `reminder_exports` table. Apple facts verified from developer.apple.com (2026-10-17): full access API iOS 17 / macOS 14; **no write-only access for reminders** (events only); `NSRemindersFullAccessUsageDescription` vs deprecated `NSRemindersUsageDescription`; `calendarItem(withIdentifier:)` read-back with the documented loss on full sync. Unverified (device rows D1–D8): iOS 16/macOS 13 prompt behaviour, whether the macOS calendars entitlement covers reminders, id stability across sync/reinstall, egress capture. Android gets nothing; macOS supported by the same plugin pending D3.
- **Product decisions left open:** Free vs Pro (`PRODUCT-DECISION` for LIC-05; no Pro tier is enforced today), approval of the full-access permission and macOS entitlement, macOS as a shipped target, default vs dedicated list.
- **Evidence:**
  - AC1: ✅ artifact: docs/adr/ADR-TSK-01-task-export.md
  - AC2: ✅ artifact: docs/adr/ADR-TSK-01-task-export.md
  - AC3: ✅ artifact: docs/adr/ADR-TSK-01-task-export.md
  - AC4: ✅ artifact: docs/adr/ADR-TSK-01-task-export.md
  - AC5: ✅ artifact: docs/privacy-audit.md; artifact: docs/threat-model.md
  - Detail: ADR E1–E10 (verified vs unverified), §3 platforms, §4 model, §6 identity; unverified items are device rows D1–D8 in docs/test-plans/device/TSK-01.md (⏳, not yet run).
