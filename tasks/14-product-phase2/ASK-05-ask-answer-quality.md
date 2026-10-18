# ASK-05 — Ask answer quality (citation precision and refusal)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** ASK-03 | **Source:** ASK-03 eval, gates AC1 missed
**Status:** in-progress
**Skills:** vv-task-workflow, vv-llm-inference, vv-benchmark-eval, vv-decision-records

## Goal
Close the two ASK-03 eval gates that the deterministic checks did not reach with the 3B: citation precision ≥ 90% and unanswerable refusal ≥ 90%, without lowering any target and without cloud calls.

## Scope
- [x] Enlarge the eval before any ASK-05 run: `tools/bench/ask/questions_ask05.json` + `answers_ask05.json` add 24 answerable and 18 unanswerable fictional questions to the ASK-03 set: **86 questions, 60 answerable, 26 unanswerable** (one miss on refusal = 3.8 points). Written from the library transcripts, committed before the first run.
- [ ] Option under test (decision by the user, 2026-10-18: 3B only, no larger model, no catalog change): a second constrained LLM pass, `AskVerifier`, that asks per cited passage (with its ±1 neighbour lines) "does this passage state the answer to the question?" with a `yes`/`no` grammar. Citations answered `no` are dropped; an answer with no citation left is refused.
- [ ] Measure on the enlarged eval: baseline (ASK-03 engine, no verifier) and with the verifier, same model and settings. Tuning of the verifier prompt is allowed for at most three iterations, every iteration is committed and reported.
- [ ] Record the decision as an ADR addendum with the measured table. If a gate is still missed, document it and propose the next step (a larger model is an explicit product decision).

**Pre-registered (before the first ASK-05 run), same targets as ASK-03, not relaxed:** citation precision ≥ 90% (gate), unanswerable refusal ≥ 90% (gate), segment recall@10 ≥ 80% (gate), answer correctness ≥ 70% (target), hallucination ≤ 15% (target). Adopt the verifier only if both gates pass on the 86 questions and the targets hold; the extra latency must keep the host median under 25 s (High-tier device budget stays ⏳ in ASK-03 AC7).

## Acceptance Criteria
- Citation precision ≥ 90% and unanswerable refusal ≥ 90% on the enlarged eval, committed report (`[ASK-05/AC1]`).
- Answer correctness ≥ 70%, hallucination ≤ 15%, segment recall@10 ≥ 80% still hold (`[ASK-05/AC2]`).
- No new network call or dependency (`[ASK-05/AC3]`, egress check).

## Notes
- ASK-03 final measured (3B, host): precision 87.5%, refusal 87.5% (7 of 8; "Who approved the vendor contract?" is answered from an unrelated meeting). The remaining wrong-recording citations are duplicate or near-duplicate statements in other recordings (E11, P07) and an ambiguous question (P03); lexical checks cannot tell them apart without hurting paraphrase questions.
