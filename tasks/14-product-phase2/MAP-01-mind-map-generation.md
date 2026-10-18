# MAP-01 — Mind-map generation

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** LLM-05, LLM-06, FND-04, FND-05, PRF-09 | **Source:** User decision 2026-10-16 (product Phase 2: mind maps)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-llm-inference, vv-pipeline-orchestrator, vv-local-database, vv-benchmark-eval, vv-decision-records, vv-testing

## Goal
Every processed recording can have a validated mind map (a bounded tree of short nodes, each tied to transcript evidence) generated on-device.

## Scope
- [x] Decide and record in `docs/adr/ADR-MAP-01-mind-map-generation.md` (Proposed) between: (A) a deterministic projection of the existing extraction JSON (title → profile sections → items; no extra LLM call, no new hallucination risk, but structure is fixed by the profile); (B) a separate grammar-constrained LLM pass that clusters the transcript or summary into concepts; (C) A as the skeleton plus B only for topic sub-nodes. Compare on the eval set below and choose by the measured result, not preference.
- [x] Tree schema and validator: node `{id, label ≤ 60 chars, children[], t?}`; limits fixed in the ADR (maximum depth and node count, proposed ≤ 3 levels and ≤ 40 nodes so it stays readable on a phone); orphan, duplicate and over-limit nodes are rejected or trimmed deterministically.
- [x] Evidence: each non-root node of an LLM-generated map carries a transcript timestamp where one exists, validated against real segment times (reuse `drop_ungrounded_timestamps` logic); labels not grounded in the transcript are dropped (reuse `ground_to_transcript` approach).
- [x] Pipeline: an optional step after extraction (FND-05 contract: persisted checkpoint, resumable, cancellable, memory residency honoured), plus on-demand generation for older recordings; a setting chooses automatic vs on-demand (default decided in the ADR, with cost in seconds and battery stated).
- [x] Storage: new table or column via a drift migration with the migration test (`vv-local-database`); deleted with the recording and, when SEC-04 expires transcripts/notes but keeps the audio (`recording_purger.dart`), with that content too; included in `search_index` only if the ADR says so.
- [x] Works with the 1B default model (no hard dependency on the 3B model) and long transcripts through the existing map-reduce path.
- [x] Eval: ≥ 30 synthetic transcripts reused from PRF-09/TPL sets with reference concept lists; metrics: schema validity, concept recall, node-label grounding rate, depth/size compliance.

## Acceptance Criteria
- ADR exists with a measured comparison of the options on the eval set (artifact) and the chosen limits.
- 100% of produced trees pass the validator (limits, unique ids, no orphans) in the eval run, and invalid model output is repaired or rejected, never stored (`[MAP-01/AC2]`).
- On the eval set with the default catalog model: schema validity ≥ 90%, label grounding ≥ 85% (threshold fixed in the ADR before the run), reported in `tools/bench/eval/baselines/`.
- Killing the app mid-step resumes or retries without a duplicate or partial map (pipeline test `[MAP-01/AC4]`).
- Mind-map seconds, RAM and battery cost per tier are written into this file with the QA-03 protocol before the first run and measured on device (device row); GATE-05 checks against them.
- Migration test from the previous schema version passes; deleting a recording, or expiring its transcript while keeping audio, removes its map (`[MAP-01/AC5]`).
- No new network host and no map text in logs (`check_egress.sh`, log-content test).

## Eval targets and cost budgets (written before the first baseline run)
Mirrored in `tools/bench/eval/mindmap/scoring.json`. These are targets, not measurements; a miss is logged as a follow-up and the target is never lowered. Reference set: 36 synthetic cases (6 per built-in profile) reused from the PRF-09/TPL sets, with reference concept lists derived from each case's hand-written `expected.json` (`tools/bench/eval/mindmap/gen_cases.py`). Default model: Llama-3.2-1B-Instruct Q4_K_M, host CPU.

| Metric (per option A / B / C) | Target |
|---|---|
| `schema_valid` (first pass; for A: the extraction the projection reads is valid) | ≥ 0.90 |
| `label_grounding` (share of non-root labels with ≥ 50 % of their key terms in the transcript, measured on the raw output **before** the grounding filter) | ≥ 0.85 |
| `concept_recall` (reference concepts matched by at least one node label) | ≥ 0.50 |
| `limits_compliance` (stored trees: depth ≤ 3, nodes ≤ 40, label ≤ 60, unique ids, no orphans) | = 1.00 |
| Option choice | highest `concept_recall` among the options that meet validity and grounding; ties go to the cheaper option |

Cost budgets of the mind-map step for a 30-minute recording (QA-03 protocol, `docs/perf.md`; measured on device in `docs/test-plans/device/MAP-01.md`; GATE-05 checks against them). Same LLM as extraction, so no additional model residency:

| Tier | Seconds (step) | Peak RAM over the extract step | Battery per 30 min recording |
|---|---|---|---|
| High | ≤ 30 | ≤ 0 MiB (same loaded model) | ≤ 1 % |
| Mid | ≤ 60 | ≤ 0 MiB | ≤ 1.5 % |
| Low | ≤ 120 | ≤ 0 MiB | ≤ 2 % |

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/MAP-01-mind-map-generation · **Date:** 2026-10-17
- **Summary:** Mind maps are generated on-device and stored in a new `mind_maps` table (drift schema v3, migration from v2, snapshot `drift_schema_v3.json`; one row per recording, cascade delete, purged with transcript expiry by `recording_purger.dart`, not in `search_index`). Domain code in `lib/features/mindmap/`: tree model, validator, deterministic normaliser (depth/node/label limits, unique ids, orphans, timestamps checked against segment times, ungrounded labels dropped), and `MindMapGenerator` with options A (projection), B (LLM topics, GBNF-constrained, long transcripts through the existing map-reduce), C (hybrid). New pipeline state `mapping` and step `mindMap` (between extract and render), registered only when the engine is wired; skipped unless the mode is `auto` or an on-demand request key is set (`SettingKeys.mindMapRequestFor`, then `rerun(mindMap)`). The tree is written inside the step's commit transaction, so a kill leaves one map or none. Eval: `tools/bench/eval/mindmap/` (`gen_cases.py`, 36 cases, `run_mindmap.py`, `app/tool/mindmap_eval_test.dart`). No Settings tile or viewer yet (would change goldens; MAP-02).
- **Baseline (measured, Llama-3.2-1B-Instruct Q4_K_M, host CPU, 36 simulated cases, one run, commit ee846aa + uncommitted MAP-01 changes):** A projection: valid 100 %, grounding 69.8 %, recall 76.6 %; B llm: 100 %, 99.7 %, 45.2 %; C hybrid: 100 %, 99.7 %, 82.7 %; limits compliance 100 % and 0 % rejected for all. By the fixed rule C is chosen and meets all four targets (A misses grounding, B misses recall). LLM call 10.2 s median / 56.6 s max on host; extraction 23.5 s median. Report `tools/bench/results/2026-10-17-eval-mindmap-Llama-3-2-1B-Instruct-Q4-K-M.md`. **Caveat:** synthetic transcripts and concepts derived from the same expected.json; a regression bar, not field accuracy.
- **Acceptance evidence:**
  - AC1: ✅ test: [MAP-01/AC1]; artifact: docs/adr/ADR-MAP-01-mind-map-generation.md
  - AC2: ✅ test: [MAP-01/AC2]
  - AC3: ✅ test: [MAP-01/AC3]; artifact: tools/bench/eval/baselines/mindmap.Llama-3-2-1B-Instruct-Q4-K-M.json
  - AC4: ✅ test: [MAP-01/AC4]; device: docs/test-plans/device/MAP-01.md
  - AC5: ⏳ test: [MAP-01/AC5]; device: docs/test-plans/device/MAP-01.md
  - AC6: ✅ test: [MAP-01/AC6]
  - AC7: ✅ test: [MAP-01/AC7]; ci: tools/ci/check_egress.sh
- **Decisions:** method C (hybrid); limits 3 levels / 40 nodes / 60 chars; default mode on-demand and not in search (PRODUCT-DECISION markers in the ADR and `mind_map_strategy.dart`); no Pro gating. Re-running from the mind-map step re-renders and rewrites the note.
- **Follow-ups:**
  - MAP-02: Settings tile for `processing.mind_map`, viewer and on-demand button (needs golden regeneration in podman).
  - Device rows: seconds, RAM and battery per tier; then decide auto vs on-demand default.
  - Re-baseline on TTS→whisper or real recordings; the LLM call reached 56.6 s max on the host for the longest transcript.
  - Product: default mode (on-demand now); whether maps should be searchable.
