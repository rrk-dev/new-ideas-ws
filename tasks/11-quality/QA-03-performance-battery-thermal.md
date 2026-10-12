# QA-03 — Performance, Battery & Thermal Benchmarking

**Workstream:** Quality | **Phase:** 2 & 4 | **Size:** M | **Depends on:** STT-04, LLM-06, FND-07 | **Source:** §5 Phase 2 (battery impact), Phase 4 (budget-device stress tests)
**Status:** todo
**Skills:** vv-task-workflow, vv-benchmark-eval, vv-background-execution, vv-llm-inference

## Goal
Know and publish the real cost of processing a recording on each device class.

## Scope
- [ ] Define performance budgets, e.g.: 60-min meeting fully processed in ≤ 15 min on High tier, ≤ 30 min on Low tier; ≤ 10% battery per hour of audio processed on High tier.
- [ ] Measure with Xcode Instruments (Energy Log, Metal) and Android Battery Historian / Perfetto.
- [ ] Thermal throttling behaviour over 30+ min sustained inference; tune thread counts and pacing.
- [ ] Target budget devices from §5 Phase 4: iPhone 11, Snapdragon 7-series phone.
- [ ] Track regressions per release.

## Acceptance Criteria
- Performance report per device class; budgets met or tier defaults adjusted (LLM-07).
