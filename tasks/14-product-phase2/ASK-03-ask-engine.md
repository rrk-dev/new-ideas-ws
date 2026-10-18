# ASK-03 — Ask-your-notes engine (retrieve, generate, cite)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** L | **Depends on:** ASK-01, ASK-02, LLM-04, LLM-05, LLM-07, FND-04, SEC-04 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes across the library)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-llm-inference, vv-local-database, vv-flutter-architecture, vv-pipeline-orchestrator, vv-privacy-security, vv-benchmark-eval, vv-testing

## Goal
A domain-layer engine answers a natural-language question about the user's library using the approach chosen in ADR-ASK-02, returning an answer with citations (recording id + timestamp) or an explicit "not found".

## Scope
- [x] Domain interface and fake (`AskEngine`, `AskAnswer`, `Citation`) following `vv-flutter-architecture` (engine interfaces with fakes); no UI here.
- [x] Retrieval per ADR-ASK-02 over transcripts and extracted fields, with an explicit optional `recordingId` scope (per-recording Ask must never retrieve another recording's passages) plus optional date/profile/tag filters parsed deterministically in Dart (not asked of the LLM).
- [x] Prompt builder and grammar-constrained answer schema (`answer`, `citations[] {recording_id, t}`, `found`) reusing the LLM-05 constrained-output path; citations are validated against retrieved passages and dropped if they do not exist.
- [x] Residency: acquire the LLM through `ModelResidency`, never while STT is resident; behaviour when a transcription job is running is the one defined in the ADR; cancel/timeout supported.
- [x] Persisted chat history only if the ADR says so, in the encrypted DB with a drift migration, deletion cascade and partial-retention handling (when SEC-04 expires transcripts/notes but keeps audio, `recording_purger.dart`, stored answers, passages and citations derived from them are purged too) (`vv-local-database`); question/answer text never logged.
- [x] Refuse politely when the 3B model is not installed or the device tier cannot run it (typed `Failure`, no crash); never fall back to a cloud call.
- [x] Eval hook in `tools/bench/eval/` that runs the ASK-02 question set end to end against the engine and reports answer correctness, citation precision, unanswerable-refusal rate, hallucination rate and latency.

## Acceptance Criteria
- On the ASK-02 question set with the 3B model on the host: citation precision ≥ 90% and unanswerable questions correctly refused ≥ 90%; the answer-correctness target is written into this file before the first run and the report is committed (artifact).
- A citation that points to a non-retrieved or non-existent passage is never returned (unit test `[ASK-03/AC2]`).
- With STT resident, asking never loads the LLM alongside it (residency unit test `[ASK-03/AC3]`).
- Deleting a recording removes it from retrieval and from any stored chat citations (DB test `[ASK-03/AC4]`).
- No question, answer or passage text appears in logs at INFO or above (log-content test `[ASK-03/AC5]`); `check_egress.sh` shows no new host.
- A per-recording Ask never returns a passage from another recording (unit/eval test `[ASK-03/AC7]`); after transcript expiry with audio retained, no stored answer or citation derived from it remains (DB test `[ASK-03/AC8]`).
- Per-tier budgets (Mid and High: median time-to-first-answer with a 100-recording library, peak RAM, thermal state) are written into this file with the measurement protocol (QA-03) before the first run and measured on device (device row); GATE-05 checks against them.

## Notes
- ADR-ASK-02 (Proposed): FTS5 BM25, k = 10 candidates, 3B at n_ctx 6144; option A measured segment recall@5 59.3% (< 80%), recall@10 80.6% — this task's end-to-end eval must also measure LLM query rewriting and decide whether the B/C spike is needed. Ask never preempts a pipeline job; see the ADR for residency, privacy and the answer contract.

## Pre-registered targets and budgets (written 2026-10-17, before the first eval run)

**End-to-end eval (AC1)** — 3B (`llama-3.2-3b-instruct-q4_k_m`, n_ctx 6144, greedy, grammar-constrained) on the host over the 44 ASK-02 questions (`tools/bench/ask/questions.json`, 33-recording synthetic library):

| Metric | Definition | Target |
|---|---|---|
| Answer correctness | Answerable questions whose `found` is true and whose answer contains all the question's expected keyword groups (case-insensitive) | ≥ 70% (target only; reported, not a ship gate) |
| Citation precision | Returned citations whose recording is a gold source for the question, over all returned citations on answerable questions | ≥ 90% (gate) |
| Unanswerable refused | Unanswerable questions answered "not found" (`found` false or no valid citation) | ≥ 90% (gate) |
| Hallucination rate | Answerable questions answered `found` with ≥ 1 valid citation but a wrong answer (keyword groups unmet) | ≤ 15% (target) |
| Segment recall@10 | Gold segments in the 10 retrieved candidates (per ADR-ASK-02) | ≥ 80% (gate; re-block + ASK-05 spike if missed) |
| Latency | Wall time per question (retrieval + load excluded + generation), median and p95 | reported only |

LLM query rewriting is measured as a second arm and adopted only if it raises segment recall@10 without lowering the citation/refusal gates. Misses are reported as measured; no number is adjusted after the run.

**Per-tier on-device budgets (AC7, QA-03 protocol in `docs/perf.md`)**: 100-recording library; cold Ask (LLM not resident) and warm Ask; 10 questions from the ASK-02 mix; median time-to-first-answer, peak RSS and thermal state read before/after.

| Tier | Median time-to-first-answer | Peak RSS | Thermal |
|---|---|---|---|
| High (3B, n_ctx 6144) | ≤ 30 s cold, ≤ 20 s warm | ≤ 4200 MiB | no worse than `fair` after 10 questions |
| Mid | not applicable: Ask is "not available" (product decision) | — | — |

Device evidence: `docs/test-plans/device/ASK-03.md` (⏳ until a High-tier device is run; GATE-05 checks against these budgets).

## Follow-ups
- **Decision needed (AC1 gates missed):** citation precision 86.0% and unanswerable refusal 87.5% are below the 90% gates. Options: (a) a verifier pass that rejects an answer whose cited passage does not contain the answer's key terms (cheap, deterministic, lowers hallucination and false answers); (b) a second constrained "is this answered by the passage?" LLM call (doubles latency); (c) accept 3B limits and relax the gates; (d) re-run on a larger model. Propose as ASK-05 (quality) rather than silently widening scope.
- Production provider wiring (Ask-specific 3B `LlmService` next to `ActiveLlmEngine`, the single `ResidentModel.llm` slot, tier and install checks, memory-pressure `cancelActive()`) is deferred to ASK-04.
- Settings registration and UI for `ask.save_history` (default on), clear-all and per-chat delete: ASK-04 (the key and the `DbAskHistory` API exist).
- Natural-language profile/tag filters ("my meetings"): only explicit `profile:id` / `#tag` / request fields are implemented.
- `tools/bench/eval/` hook lives in `tools/bench/ask/ask_eval.py` + `app/test/eval/ask_eval_host_test.dart` (the engine imports Flutter, so it cannot run under plain `dart run`).
- The eval used the host bridge `libvv_native.dylib` built in the main checkout (same pinned submodules); `native/build.sh host` builds it in a fresh worktree.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/ASK-03-ask-engine · **Date:** 2026-10-17
- **Summary:** `AskService` (domain, with `AskEngine` interface and `FakeAskEngine`) answers from the library with FTS5 retrieval (k = 10, ±1 neighbours, SQL date/recording/profile/tag filters), a grammar-constrained answer schema restricted to the retrieved passages, citation validation, ModelResidency exclusion (never loads the LLM beside STT, never preempts the pipeline, memory gate, idle unload), typed refusals (device tier, 3B missing), content-free logs, and persisted chat history (drift schema v3 + migration test; 30-day expiry in the retention sweep; purge on recording delete and transcript expiry). Measured on the host with the real 3B over 44 questions: segment recall@10 **91.7% (gate met)**, answer correctness **72.2% (target met)**, hallucination **13.9% (target met)**, but citation precision **86.0% (< 90%, gate NOT met)** and unanswerable refusal **87.5% (< 90%, gate NOT met)**. LLM query rewrite: do not adopt (recall 91.7% → 80.6%). Four runs, all committed (engine tweaks between runs are listed in ADR-ASK-02).
- **Acceptance evidence:**
  - AC1: ❌ gates not met (precision 86.0%, refusal 87.5%; targets pre-registered, report committed) artifact: tools/bench/results/2026-10-17-ask03-eval.md; artifact: tools/bench/ask/ask_eval.py; artifact: tools/bench/results/2026-10-17-ask03-eval-run1.md
  - AC2: ✅ test: [ASK-03/AC2]
  - AC3: ✅ test: [ASK-03/AC3]
  - AC4: ✅ test: [ASK-03/AC4]
  - AC5: ✅ test: [ASK-03/AC5]; artifact: tools/ci/check_egress.sh
  - AC6: ✅ test: [ASK-03/AC6]
  - AC7: ⏳ device: docs/test-plans/device/ASK-03.md
- **Decisions:** Ask is Free and uses the 3B (product decision, no Pro enforcement); Mid/Low show "not available"; history on by default, 30-day expiry (ADR-ASK-02 product decisions). Query rewrite not adopted. Schema `answer, citations, found` with `found` last (measured: correctness 44.4% → 77.8%); a deterministic grounding check (run 4) raised refusal 75.0% → 87.5% but lowered multi-recording correctness.
- **Device-dependent:** AC7 budgets (High tier cold ≤ 30 s, warm ≤ 20 s, RSS ≤ 4200 MiB, thermal ≤ `fair`) need a High-tier phone; host latency median 15.2 s / p95 26.5 s on CPU under load is not a device number.
