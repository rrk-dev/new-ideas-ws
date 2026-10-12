# SEC-07 — Recording Consent Features

**Workstream:** Security & Privacy | **Phase:** 3–4 | **Size:** S | **Depends on:** AUD-08, SEC-09 | **Source:** Gap (two-party consent laws; target users record meetings)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-audio-capture, vv-markdown-vault-export, vv-extraction-profiles, vv-local-database, vv-testing

## Goal
Make sure every recording is a deliberate act of the device user, and that the user is reminded to obtain consent from everyone being recorded.

## Scope
- [ ] First-run recording-consent explainer that the user must acknowledge before the first recording (one-party vs all-party consent; record only with permission; never record calls).
- [ ] Per-recording confirmation for multi-person profiles (Meeting, Engineering, Auto): "Everyone present knows and agrees to this recording" — default **on**. Whether users may turn it off is a product/legal decision (record it in an ADR as `Proposed`).
- [ ] Personal profiles (voice notes, Warranty) may skip the per-recording confirmation, but still require the first-run acknowledgement.
- [ ] Profile key `consent_confirmation: required | optional | none` (profile spec) drives the per-recording step.
- [ ] Store `consent_confirmed_at` on each recording (and optional spoken-consent marker); include `consent_at` in note front-matter.
- [ ] Visible recording indicator; never record silently/hidden (enforced by SEC-09).

## Acceptance Criteria
- A multi-person-profile recording cannot start until the confirmation is accepted (widget test + device test).
- Consent metadata appears in exported Markdown.
- Wording reviewed by product/legal (task stays `review` until confirmed).
