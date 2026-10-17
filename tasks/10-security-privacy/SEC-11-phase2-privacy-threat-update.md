# SEC-11 — Phase 2 privacy, egress and threat-model update

**Workstream:** Security & Privacy | **Phase:** 5 | **Size:** M | **Depends on:** SEC-02, SEC-06, SEC-08, QCP-02, QCP-03, ASK-03, MAP-01, TSK-02 | **Source:** User decision 2026-10-16 (product Phase 2); Gap (new data flows need re-audit)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-ci-release, vv-testing

## Goal
The privacy promise, store disclosures and threat model remain true after quick capture, ask-your-notes, mind maps and task export ship.

## Scope
- [ ] Confirm no third-party integration host or credential code ships (Todoist and Apple Notes were dropped 2026-10-17); apply any privacy-doc amendments ADR-TSK-01 required (human-approved).
- [ ] Update `docs/privacy-audit.md`: new native targets and App Group data (what the widget extension can read), stored chat history and mind maps (encryption, backup exclusion, deletion), Reminders access (on-device), exactly which text the user selected for export to Reminders.
- [ ] Update `docs/threat-model.md` with: widget/App Intent/tile spoofing or replay of start requests, another app invoking the intent, content leaking onto Lock Screen surfaces, prompt injection through transcripts into Ask answers and mind-map labels (including model output rendered into Markdown), retrieval returning another user profile's data on shared devices, and export of text the user did not select.
- [ ] Re-run the dependency/licence review for anything added by Phase 2 (`tools/ci` dependency checks, `docs/licenses.md`, Llama 3.2 3B attribution) and the egress test over the full Phase 2 flows.
- [ ] Extend automated checks where a rule can be machine-checked: the egress script covers any new integration host by name; the recording-policy script covers the new native targets and manifest components; a test asserts widget/control data contains no recording-derived fields.
- [ ] Update store privacy answers and listings (SEC-06: Apple privacy manifest / App Privacy answers, Google Data Safety) and `docs/store/` text for the new permissions and data flows.
- [ ] Re-run the log-content test over the new features (no question/answer, mind-map, reminder or task text at INFO or above).

## Acceptance Criteria
- Every new data flow appears in `docs/privacy-audit.md` with data, location, protection and deletion path; a checklist row per flow is signed (artifact).
- `docs/threat-model.md` lists each threat above with a mitigation and the test or control that proves it.
- `check_egress.sh`, `check_recording_policy.sh` and the egress proxy test pass on the Phase 2 build; the only network hosts are those in the audit (CI output).
- Store privacy answers match the audit; a human signs the SEC-06 row (device/human row `docs/test-plans/device/SEC-11.md`, ⏳ until done).
- Log-content and widget-data tests pass (`[SEC-11/AC5]`).
