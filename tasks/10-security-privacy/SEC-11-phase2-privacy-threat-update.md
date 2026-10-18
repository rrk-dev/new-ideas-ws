# SEC-11 — Phase 2 privacy, egress and threat-model update

**Workstream:** Security & Privacy | **Phase:** 5 | **Size:** M | **Depends on:** SEC-02, SEC-06, SEC-08, QCP-02, QCP-03, ASK-03, MAP-01, TSK-02 | **Source:** User decision 2026-10-16 (product Phase 2); Gap (new data flows need re-audit)
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-ci-release, vv-testing

## Goal
The privacy promise, store disclosures and threat model remain true after quick capture, ask-your-notes, mind maps and task export ship.

## Scope
- [x] Confirm no third-party integration host or credential code ships (Todoist and Apple Notes were dropped 2026-10-17); apply any privacy-doc amendments ADR-TSK-01 required (human-approved).
- [x] Update `docs/privacy-audit.md`: new native targets and App Group data (what the widget extension can read), stored chat history and mind maps (encryption, backup exclusion, deletion), Reminders access (on-device), exactly which text the user selected for export to Reminders.
- [x] Update `docs/threat-model.md` with: widget/App Intent/tile spoofing or replay of start requests, another app invoking the intent, content leaking onto Lock Screen surfaces, prompt injection through transcripts into Ask answers and mind-map labels (including model output rendered into Markdown), retrieval returning another user profile's data on shared devices, and export of text the user did not select.
- [x] Re-run the dependency/licence review for anything added by Phase 2 (`tools/ci` dependency checks, `docs/licenses.md`, Llama 3.2 3B attribution) and the egress test over the full Phase 2 flows.
- [x] Extend automated checks where a rule can be machine-checked: the egress script covers any new integration host by name; the recording-policy script covers the new native targets and manifest components; a test asserts widget/control data contains no recording-derived fields.
- [x] Update store privacy answers and listings (SEC-06: Apple privacy manifest / App Privacy answers, Google Data Safety) and `docs/store/` text for the new permissions and data flows.
- [x] Re-run the log-content test over the new features (no question/answer, mind-map, reminder or task text at INFO or above).

## Acceptance Criteria
- Every new data flow appears in `docs/privacy-audit.md` with data, location, protection and deletion path; a checklist row per flow is signed (artifact).
- `docs/threat-model.md` lists each threat above with a mitigation and the test or control that proves it.
- `check_egress.sh`, `check_recording_policy.sh` and the egress proxy test pass on the Phase 2 build; the only network hosts are those in the audit (CI output).
- Store privacy answers match the audit; a human signs the SEC-06 row (device/human row `docs/test-plans/device/SEC-11.md`, ⏳ until done).
- Log-content and widget-data tests pass (`[SEC-11/AC5]`).

## Open Decisions
- Human sign-off (owner): the SEC-06 store-answer row and the per-flow checklist (`docs/test-plans/device/SEC-11.md` SEC-11-D7 and D9) are ⏳ until a human signs them; the audit text is engineering sign-off only.
- Live Activity (AUD-13) is not merged, so it is not audited; SEC-11-D8 reopens it when it lands.
- The System boot time reason code `35F9.1` for `ProcessInfo.systemUptime` comes from Apple's published list found by web search; confirm it in an Archive privacy report (SEC-11-D1).
- Real-device egress capture over Ask, Reminders, widgets, Share and the 3B download is a device row (SEC-11-D2); the host proxy test and the static checks are what ran here.

## Follow-ups
- Re-run this audit when AUD-13 (Live Activity) merges, and when any new native target, permission or host is added.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/SEC-11-phase2-privacy-audit · **Date:** 2026-10-18
- **Summary:** Audited the Phase 2 flows on `main` (`bbe43e4`). One real finding (F1): `QuickCaptureStore.swift` uses `ProcessInfo.systemUptime` (System boot time required-reason API) that no manifest declared and the SEC-06 check could not see. Fixed: Runner manifest entry, new bundled `LumenWidgets/PrivacyInfo.xcprivacy` (verified present in an unsigned `LumenWidgets.appex` build), and `check_store_privacy` now scans `QuickCaptureShared`, `LumenWidgets` and `ShareExtension`. `check_egress.sh` now rejects integration hosts and credential code by name. Docs: `privacy-audit.md` (Phase 2 flows P1–P8, what the widget can read, findings, commands run, checklist, DRAFT sections finalised), `threat-model.md` (T23–T32 with proofs, T17–T22 finalised), store docs, `licenses.md` and its generator header (stale "no Llama model" text), `ci.md`. New tests `app/test/unit/security/phase2_privacy_test.dart` (log content for Ask, Reminders, mind-map Markdown; plain-text Ask render; widget/tile/extension source scan; doc coverage) and pytest cases. No dependency or host was added by Phase 2 (125 packages pass `check_packages.sh`).
- **Not verified here:** real-device egress, Archive privacy report, macOS Reminders entitlement, Personal Team App Group, Lock Screen content, Live Activity, human sign-offs: all ⏳ rows in `docs/test-plans/device/SEC-11.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [SEC-11/AC1]
  - AC2: ✅ test: [SEC-11/AC2]
  - AC3: ✅ test: [SEC-11/AC3]
  - AC4: ⏳ device: docs/test-plans/device/SEC-11.md
  - AC5: ✅ test: [SEC-11/AC5]
