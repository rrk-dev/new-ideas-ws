# PRF-07 — Custom Profile Editor (Pro)

**Workstream:** Profiles | **Phase:** 3 | **Size:** L | **Depends on:** PRF-01, PRF-02, LIC-01 | **Source:** §7 (Unlimited domain extraction profiles — Pro)
**Status:** todo
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-flutter-architecture, vv-licensing-iap, vv-markdown-vault-export, vv-testing

## Goal
Pro users create their own extraction profiles (e.g., Sprint Planning, Legal Intake, Patient Notes) without writing JSON Schema by hand.

## Scope
- [ ] Create from scratch or duplicate a built-in.
- [ ] Field builder UI (name, type: text/list/date/number/checkbox list/table, description) → generates JSON Schema.
- [ ] Instruction text editor + optional examples.
- [ ] "Test on a recording" button: run against a selected transcript and show JSON + rendered Markdown.
- [ ] Generate a default template with the generic template generator (`vv-markdown-vault-export`), editable in EXP-07; bind it (EXP-01) and the routing target (EXP-05).
- [ ] Free tier limited to built-in profiles (gate via LIC-01).

## Acceptance Criteria
- A user can build a 5-field custom profile and get a correct export without touching raw JSON.
- Profiles survive app updates and DB migrations.
