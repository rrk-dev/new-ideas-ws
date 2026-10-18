# ASK-05 — Ask answer quality (citation precision and refusal)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** ASK-03 | **Source:** ASK-03 eval, gates AC1 missed
**Status:** todo
**Skills:** vv-task-workflow, vv-llm-inference, vv-benchmark-eval, vv-decision-records

## Goal
Close the two ASK-03 eval gates that the deterministic checks did not reach with the 3B: citation precision ≥ 90% and unanswerable refusal ≥ 90%, without lowering any target and without cloud calls.

## Scope
- [ ] Measure the options on the committed eval (`tools/bench/ask/ask_eval.py`, same 44 questions plus new ones so the refusal set is larger than 8): (a) a second constrained "does this passage answer the question?" call per citation, (b) a larger local model for Ask, (c) cross-recording duplicate handling in the citation step.
- [ ] Add questions before running: the unanswerable set has 8 items, so one miss is 12.5 points; grow it to at least 20 and the answerable set to at least 50, written before the run.
- [ ] Record the decision as an ADR addendum with the measured table; adopt only options that meet both gates and keep correctness ≥ 70%, hallucination ≤ 15% and the High-tier latency budget (ASK-03 AC7).

## Acceptance Criteria
- Citation precision ≥ 90% and unanswerable refusal ≥ 90% on the enlarged eval, committed report (`[ASK-05/AC1]`).
- Answer correctness ≥ 70%, hallucination ≤ 15%, segment recall@10 ≥ 80% still hold (`[ASK-05/AC2]`).
- No new network call or dependency (`[ASK-05/AC3]`, egress check).

## Notes
- ASK-03 final measured (3B, host): precision 87.5%, refusal 87.5% (7 of 8; "Who approved the vendor contract?" is answered from an unrelated meeting). The remaining wrong-recording citations are duplicate or near-duplicate statements in other recordings (E11, P07) and an ambiguous question (P03); lexical checks cannot tell them apart without hurting paraphrase questions.
