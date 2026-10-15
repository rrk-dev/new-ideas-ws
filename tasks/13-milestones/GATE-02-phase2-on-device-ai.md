# GATE-02 — Phase 2 Gate: On-Device Transcription & Structured Extraction

**Workstream:** Milestones | **Phase:** 2 | **Size:** M | **Depends on:** GATE-01, FND-05, AUD-03, STT-03, STT-04, STT-07, LLM-04, LLM-05, LLM-07, MDL-01, MDL-02, QA-02 | **Source:** §5 Phase 2 + verification strategy
**Status:** review
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-benchmark-eval, vv-pipeline-orchestrator

## Goal
A recording becomes a transcript and schema-valid structured JSON entirely on-device, within memory limits, on low- and high-tier devices.

## Scope
- [x] Scenario script `docs/test-plans/gates/GATE-02.md` + `integration_test` for the pipeline with real tiny models.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-02.md): Run on one Low-tier and one High-tier device per platform with the tier-default models.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-02.md): Attach WER/RTF and tokens/s results produced with `vv-benchmark-eval`.

## Acceptance Criteria
- Fresh install → model download (with progress) → 30-min recording → transcript → schema-valid JSON on a Low-tier and a High-tier device per platform, with no OOM kill.
- Force-kill during transcription and during extraction → the job resumes and completes with no duplicate segments.
- Airplane mode during the whole run after model download: pipeline completes (zero network use).
- Benchmark report committed: WER per model on the QA-02 corpus and end-to-end processing time per device.
- `tasks.py verify --all-done --run` green on `main`; all dependencies `done`.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/gates · **Date:** 2026-10-15
- **Summary:** Scenario script `docs/test-plans/gates/GATE-02.md`, automatable `app/integration_test/gate_02_pipeline_test.dart` (fakes for hardware; compiles under analyze, logic also run on the host), and device rows in `docs/test-plans/device/GATE-02.md` (all ⏳). Enterprise/MDM (LIC-04) is out of scope and dropped from this gate. Dependencies are still in `review`, so the gate cannot become `done` yet.
- **Acceptance evidence:**
  - AC1: ⏳ test: [GATE-02/AC1]; device: docs/test-plans/device/GATE-02.md
  - AC2: ⏳ test: [GATE-02/AC2]; device: docs/test-plans/device/GATE-02.md
  - AC3: ⏳ test: [GATE-02/AC3]; device: docs/test-plans/device/GATE-02.md
  - AC4: ⏳ device: docs/test-plans/device/GATE-02.md
  - AC5: ⏳ ci: tasks.py verify --all-done --run on main (human)
- **Decisions:** none.
- **Follow-ups:**
  - Human: run the device rows on the QA-05 matrix; a different tool or a human verifies after all dependencies are `done`.
