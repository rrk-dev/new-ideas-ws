# SEC-07 — Recording Consent Features

**Workstream:** Security & Privacy | **Phase:** 3–4 | **Size:** S | **Depends on:** AUD-08, SEC-09 | **Source:** Gap (two-party consent laws; target users record meetings)
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-audio-capture, vv-markdown-vault-export, vv-extraction-profiles, vv-local-database, vv-testing

## Goal
Make sure every recording is a deliberate act of the device user, and that the user is reminded to obtain consent from everyone being recorded.

## Scope
- [x] First-run recording-consent explainer that the user must acknowledge before the first recording (one-party vs all-party consent; record only with permission; never record calls).
- [x] Per-recording confirmation for multi-person profiles (Meeting, Engineering, Auto): "Everyone present knows and agrees to this recording" — default **on**. Whether users may turn it off is a product/legal decision (record it in an ADR as `Proposed`).
- [x] Personal profiles (voice notes, Warranty) may skip the per-recording confirmation, but still require the first-run acknowledgement.
- [x] Profile key `consent_confirmation: required | optional | none` (profile spec) drives the per-recording step.
- [x] Store `consent_confirmed_at` on each recording (and optional spoken-consent marker); include `consent_at` in note front-matter.
- [x] Visible recording indicator; never record silently/hidden (enforced by SEC-09, AUD-04/05/08 indicators; nothing added here).

## Acceptance Criteria
- A multi-person-profile recording cannot start until the confirmation is accepted (widget test + device test).
- Consent metadata appears in exported Markdown.
- Wording reviewed by product/legal (task stays `review` until confirmed).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/expsec · **Date:** 2026-10-15
- **Summary:** The Record tap now needs (1) the first-run acknowledgement (asked again in a dialog if onboarding did not store it) and (2) the per-recording "Everyone present agrees" dialog for `required` profiles and for Auto; `optional` profiles get the same dialog plus "Record without confirming"; `none` starts directly. Confirming stores `recordings.consent_confirmed_at`, and the note front-matter gets `consent_at` only then. `RecordingSessionService.addSpokenConsentMarker` stores an optional `markers.kind = consent`. ADR-SEC-07 records the "may users turn it off" question as Proposed.
- **Acceptance evidence:**
  - AC1: ⏳ test: [SEC-07/AC1]; device: docs/test-plans/device/SEC-07.md
  - AC2: ⏳ test: [SEC-07/AC2]; device: docs/test-plans/device/SEC-07.md
  - AC3: ⏳ device: docs/test-plans/device/SEC-07.md
- **Decisions:** docs/adr/ADR-SEC-07-recording-consent.md (Proposed)
- **Follow-ups:** none beyond those below.

## Follow-ups
- Product/legal: approve the wording (explainer, both dialogs, never-calls text) and decide ADR-SEC-07 (may users turn the confirmation off?).
- No UI button yet for the spoken-consent marker (service method and storage only); add it in the recording screen if product wants it.
