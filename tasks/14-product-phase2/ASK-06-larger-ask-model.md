# ASK-06 — Larger Ask model (≈7–9B) with download warning

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** L | **Depends on:** ASK-05 | **Source:** ASK-05 follow-up; product decision 2026-10-19 (option A)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-llm-inference, vv-benchmark-eval, vv-decision-records, vv-model-delivery

## Goal
Close the ASK-03/ASK-05 Ask quality gates that the 3B misses by evaluating a larger instruct model (≈7–9B, Q4_K_M) on the same 86-question eval with the same pre-registered targets, and ship the winner as an explicit-selection model with a clear warning (size, RAM, slower answers).

## Scope
- [ ] ADR (`docs/adr/ADR-ASK-06-larger-ask-model.md`): 2–3 candidates, licences from the official model cards, pinned revision, sha256 and size from the downloaded file, chat-template support verified in the pinned llama.cpp; no new network host.
- [ ] Measure the candidates on the 86-question eval (same method/settings as the ASK-05 baseline); record peak RSS, tokens/s, median latency; report under `tools/bench/results/2026-10-19-ask06-<model>.md`.
- [ ] If a candidate meets (or clearly improves on the 3B, as "experimental"): add it to `tools/model-catalog/models.json`, update `docs/models.md`, `docs/licenses.md`, notices.
- [ ] App wiring: Ask prefers the larger model when installed, else the 3B; memory estimate/gates from the measured peak; macOS relaxed free-memory rule coherent; STT and LLM never resident together.
- [ ] Pre-download WARNING in the model manager / Ask download prompt (size, free RAM, slower, may still err), l10n strings.
- [ ] Tests tagged `[ASK-06/ACn]`; device-only items in `docs/test-plans/device/ASK-06.md`.

**Pre-registered (not relaxed, same as ASK-05):** citation precision ≥ 90% (gate), unanswerable refusal ≥ 90% (gate), segment recall@10 ≥ 80% (gate), answer correctness ≥ 70% (target), hallucination ≤ 15% (target).

## Acceptance Criteria
- ADR with candidates, licences, pinned revisions and measured evidence (`[ASK-06/AC1]`).
- Committed eval report(s) on the 86 questions with peak RSS, tokens/s and median latency; each gate reported honestly (`[ASK-06/AC2]`).
- Catalog entry validates against the schema and the catalog tooling tests pass; docs/licences updated (`[ASK-06/AC3]`).
- Ask uses the larger model when installed and falls back to the 3B otherwise (`[ASK-06/AC4]`).
- A download warning with size, RAM and slower-answers text is shown before the download (`[ASK-06/AC5]`).
- No new network host or dependency (`[ASK-06/AC6]`, egress check).
- On-device speed and memory of the larger model on a High-tier phone (device checklist).
