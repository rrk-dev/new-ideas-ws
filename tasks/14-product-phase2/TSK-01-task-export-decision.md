# TSK-01 — Action-item export decision: Apple Reminders and Todoist (privacy and egress)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** S | **Depends on:** SEC-02, SEC-06, SEC-08, APP-05, EXP-05 | **Source:** User decision 2026-10-16 (product Phase 2: push action items to Apple Reminders or Todoist; needs an egress policy check)
**Status:** todo
**Skills:** vv-task-workflow, vv-decision-records, vv-privacy-security, vv-markdown-vault-export, vv-licensing-iap

## Goal
Decide whether and how extracted action items may be pushed to Apple Reminders (local) and Todoist (a third-party cloud service) without weakening the "no user content leaves the device" promise.

## Scope
- [ ] State the policy tension plainly: Reminders via EventKit is an on-device OS API (iCloud sync of Reminders is the user's own OS setting, outside our client); Todoist sends task text to a third-party server over HTTPS and so breaks the current egress allowlist (model catalog/CDN only, `kModelHosts`).
- [ ] Verify against official documentation (record versions and URLs): EventKit reminder access on the iOS and macOS versions we target (access levels, required Info.plist usage-description keys, macOS sandbox entitlement), Android has no Reminders equivalent (state what Android users get); Todoist's current public API (version, base host, OAuth vs personal token, scopes, rate limits, task fields for content/due/labels, how to avoid duplicates).
- [ ] Decide for Todoist: ship, ship behind an explicit opt-in, or do not ship in v1. If shipping, define: per-push user confirmation showing exactly which text leaves the device; a separate "Integrations" switch that is off by default and off in offline mode / when MDM sets `network_disabled`; secrets stored only in the platform secure store; the single new allowlisted host and how `NetworkGateway`, `check_egress.sh`, ATS/Network Security Config and the egress test change; the effect on the store privacy labels/Data Safety form (SEC-06) and the threat model (SEC-08).
- [ ] Define the shared domain model used by both exporters: which `action_items` rows are eligible (`done` false, with `body`; `owner` shown as text only; `due_iso` used as a due date only when present, never guessed from spoken text), the user-selects-items step (reuse the APP-05 review/selection UI), idempotency (remember external ids per item so a second push updates or skips instead of duplicating) and failure handling (EXP-06 outbox semantics or none, decided).
- [ ] Decide Free vs Pro placement as an explicit `PRODUCT-DECISION` for LIC-05; do not assume.
- [ ] Write `docs/adr/ADR-TSK-01-task-export.md` (Proposed) and update `docs/privacy-audit.md` and `docs/threat-model.md` drafts (final updates in SEC-11).

## Acceptance Criteria
- The ADR cites the official EventKit and Todoist documentation pages with the versions checked, and states for every claim whether it was verified or is a device-row item.
- The ADR gives a go / opt-in / no-go decision for Todoist with the exact data sent per request, the allowlisted host, the secret storage and the offline/MDM behaviour, and requires human approval before TSK-03 starts.
- The shared item model, eligibility rules and idempotency scheme are specified precisely enough to write tests from.
- The Android position (no Reminders; Todoist only if approved) and the macOS position are stated.
- `docs/privacy-audit.md` and `docs/threat-model.md` contain draft sections for the new data flows (artifact).

## Notes
- Google Tasks, Asana, calendar events and email are out of scope.
- The user must approve the Todoist outcome; this task must not add any host to the allowlist.
