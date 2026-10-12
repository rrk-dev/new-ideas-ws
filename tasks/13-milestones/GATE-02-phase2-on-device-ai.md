# GATE-02 — Phase 2 Gate: On-Device Transcription & Structured Extraction

**Workstream:** Milestones | **Phase:** 2 | **Size:** M | **Depends on:** GATE-01, FND-05, AUD-03, STT-03, STT-04, STT-07, LLM-04, LLM-05, LLM-07, MDL-01, MDL-02, QA-02 | **Source:** §5 Phase 2 + verification strategy
**Status:** todo
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-benchmark-eval, vv-pipeline-orchestrator

## Goal
A recording becomes a transcript and schema-valid structured JSON entirely on-device, within memory limits, on low- and high-tier devices.

## Scope
- [ ] Scenario script `docs/test-plans/gates/GATE-02.md` + `integration_test` for the pipeline with real tiny models.
- [ ] Run on one Low-tier and one High-tier device per platform with the tier-default models.
- [ ] Attach WER/RTF and tokens/s results produced with `vv-benchmark-eval`.

## Acceptance Criteria
- Fresh install → model download (with progress) → 30-min recording → transcript → schema-valid JSON on a Low-tier and a High-tier device per platform, with no OOM kill.
- Force-kill during transcription and during extraction → the job resumes and completes with no duplicate segments.
- Airplane mode during the whole run after model download: pipeline completes (zero network use).
- Benchmark report committed: WER per model on the QA-02 corpus and end-to-end processing time per device.
- `tasks.py verify --all-done --run` green on `main`; all dependencies `done`.
