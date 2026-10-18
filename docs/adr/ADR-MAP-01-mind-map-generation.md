# ADR-MAP-01 — Mind-map generation

- **Status:** Proposed
- **Date:** 2026-10-17
- **Task:** MAP-01
- **Deciders:** Copilot agent; human reviewer pending
- **Supersedes:** —

## Context

Every processed recording can get a bounded, validated mind map generated on-device with the
default 1B model (English only, no cloud). Options to compare on the same eval set
(`tools/bench/eval/mindmap/`, 36 simulated transcripts, 197 reference concepts derived from the
PRF-09/TPL `expected.json` files):

1. **A. Projection:** a deterministic tree built from the existing extraction JSON and transcript
   segments. No extra LLM call.
2. **B. LLM:** a separate grammar-constrained pass that returns topic nodes.
3. **C. Hybrid:** A as the skeleton plus B only for topic sub-nodes.

## Criteria (fixed in the task file before the first run)

| Criterion | Threshold |
|---|---|
| `schema_valid` | ≥ 0.90 |
| `label_grounding` (raw labels, before the grounding filter) | ≥ 0.85 |
| `concept_recall` | ≥ 0.50 |
| `limits_compliance` | = 1.00 |
| Choice rule | highest `concept_recall` among options meeting validity and grounding; ties go to the cheaper option |

## Evidence

Measured on 2026-10-17, host Apple Silicon CPU, Llama-3.2-1B-Instruct Q4_K_M, 36 cases
(`tools/bench/results/2026-10-17-eval-mindmap-Llama-3-2-1B-Instruct-Q4-K-M.md`,
baseline `tools/bench/eval/baselines/mindmap.Llama-3-2-1B-Instruct-Q4-K-M.json`).

| Option | schema_valid | label_grounding | concept_recall | limits_compliance | rejected | avg nodes |
|---|---|---|---|---|---|---|
| A projection | 100.0% | 69.8% | 76.6% | 100.0% | 0.0% | 18.9 |
| B llm | 100.0% | 99.7% | 45.2% | 100.0% | 0.0% | 8.5 |
| C hybrid | 100.0% | 99.7% | 82.7% | 100.0% | 0.0% | 27.1 |

- A fails the grounding bar: labels copied from extraction fields (normalised values, product
  names) are less often literal transcript words. B has high grounding but misses the
  profile-specific concepts. C meets every threshold and has the best recall.
- The extraction that A and C read was valid in 100% of the cases (median 23.5 s per case on the
  host, long-transcript map-reduce path included).
- Added cost over extraction: A none (< 0.02 s); B and C share one LLM call, median 10.2 s, max
  56.6 s on the host (the report's per-option latency counts that call once, under B).
- The eval transcripts are synthetic and more regular than real speech; the numbers are a
  regression bar, not a field accuracy. Device seconds, RAM and battery are **unmeasured**
  (`docs/test-plans/device/MAP-01.md`, ⏳).

## Decision

1. **Method: C (hybrid)** by the choice rule. `kDefaultMindMapMethod` = hybrid.
2. **Limits:** depth ≤ 3 levels (root = level 1), ≤ 40 nodes, label ≤ 60 characters, unique ids,
   no orphans. Over-limit trees are trimmed deterministically (`normalizeMindMap`); a tree that
   still fails validation is rejected and never stored.
3. **Evidence:** timestamps are kept only when they match a real segment time; labels with less
   than 50% of their key terms in the transcript are dropped.
4. **Default mode: on demand** (`processing.mind_map` = `on_demand`).
   PRODUCT-DECISION: the step adds a model call to every job (≈10 s median on a host CPU, device
   cost unmeasured), so automatic generation waits for the device rows against the budgets
   (High ≤ 30 s, Mid ≤ 60 s, Low ≤ 120 s). On demand uses a request key and re-running from the
   mind-map step; re-running re-renders the note. No tier gating (no Pro enforcement).
5. **Search:** the map is **not** indexed in `search_index` (the labels repeat extraction
   content that is already searchable).
6. **Storage:** `mind_maps` table (schema v3), one row per recording, written in the same
   transaction that advances the job, so a kill mid-step cannot leave a duplicate or partial map.
   Deleted with the recording and when SEC-04 expires transcripts/notes.

## Consequences

- No new network host; no new model residency (the extraction model is reused).
- Option C reads option A's extraction; when the extraction is not valid, the hybrid falls back
  to B's topic nodes alone, and the map is rejected if that is empty.
- Follow-ups: device cost rows, a viewer UI (MAP-02), re-measuring on real recordings.
