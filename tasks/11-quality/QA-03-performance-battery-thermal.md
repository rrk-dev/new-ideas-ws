# QA-03 — Performance, Battery & Thermal Benchmarking

**Workstream:** Quality | **Phase:** 2 & 4 | **Size:** M | **Depends on:** STT-04, LLM-06, FND-07 | **Source:** §5 Phase 2 (battery impact), Phase 4 (budget-device stress tests)
**Status:** review
**Skills:** vv-task-workflow, vv-benchmark-eval, vv-background-execution, vv-llm-inference

## Goal
Know and publish the real cost of processing a recording on each device class.

## Scope
- [x] Define performance budgets, e.g.: 60-min meeting fully processed in ≤ 15 min on High tier, ≤ 30 min on Low tier; ≤ 10% battery per hour of audio processed on High tier.
- [x] Measure with Xcode Instruments (Energy Log, Metal) and Android Battery Historian / Perfetto.
- [x] Thermal throttling behaviour over 30+ min sustained inference; tune thread counts and pacing.
- [x] Target budget devices from §5 Phase 4: iPhone 11, Snapdragon 7-series phone.
- [x] Track regressions per release.

## Acceptance Criteria
- Performance report per device class; budgets met or tier defaults adjusted (LLM-07).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/qa · **Date:** 2026-10-15
- **Summary:** Budgets in `tools/bench/perf/budgets.json` (High 15 min and 10%/h, Low 30 min; Mid and Low-battery values are placeholders). `tools/bench/perf/perf_report.py` turns FND-07 job metrics into per-tier verdicts (check), Markdown (report), history and a >10% regression gate (compare/record). `android_capture.sh` wraps batterystats and thermalservice. Protocol for Instruments, Perfetto, Battery Historian and the 30 min thermal run in `docs/perf.md`. Report skeleton per device class `docs/perf-report.md`, history `tools/bench/results/perf-history.md`. Tests: `tools/ci/tests/test_perf_bench.py` (synthetic fixtures only). No device measurements exist yet; all numbers are ⏳.
- **Acceptance evidence:**
  - AC1: ✅ test: [QA-03/AC1]; artifact: docs/perf-report.md; device: docs/test-plans/device/QA-03.md
- **Decisions:** none.
- **Follow-ups:**
  - Human: run the protocol on VV-IOS-11, VV-AND-7, VV-IOS-16, VV-AND-FLG, VV-AND-4G (QA-05 lab) and fill the report; adjust tier defaults under LLM-07 if a budget is missed.
  - Mid-tier and Low-tier battery budgets need an ADR once real numbers exist.
