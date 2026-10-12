# QA-01 — Test Strategy & Automated Test Framework

**Workstream:** Quality | **Phase:** 1 | **Size:** M | **Depends on:** FND-02, FND-03 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-testing, vv-ci-release

## Goal
A test pyramid that keeps the pipeline reliable as models/prompts change.

## Scope
- [ ] Unit tests (domain, rules engine, templates, sanitization, entitlements) — coverage target ≥ 80% for `lib/**/domain/**` and `lib/core/**`.
- [ ] Widget tests for every screen state; golden tests for key screens.
- [ ] Integration tests (`integration_test`) for record → transcribe → extract → export using tiny models on device/simulator.
- [ ] Fake engines (FND-02) for fast pipeline tests in CI without models.
- [ ] Test fixtures: short audio clips, transcripts, expected Markdown.

## Acceptance Criteria
- Acceptance-tag convention (`[<ID>/ACn]`) and device-checklist location documented in `docs/testing.md`; one example tagged test and one example device checklist committed.
- `docs/testing.md` defines layers, ownership and gates; CI enforces coverage threshold.
