# ASK-02 — Ask-your-notes retrieval decision (FTS5 vs embeddings, context budget, privacy)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** APP-02, LLM-06, LLM-07, SEC-01, SEC-04, PRF-09 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes across the library)
**Status:** todo
**Skills:** vv-task-workflow, vv-decision-records, vv-llm-inference, vv-local-database, vv-benchmark-eval, vv-privacy-security, vv-model-delivery

## Goal
Decide, with measurements, how a question is answered from the user's own library fully on-device: how passages are retrieved, how many fit in the context window, and how answers cite their sources.

## Scope
- [ ] Options to compare (all offline): (A) FTS5 BM25 over the existing `search_index` (transcripts + extracted fields) with query rewriting by the LLM; (B) a small on-device embedding model plus a vector store (needs a new catalog model, a new native or Dart dependency and a new download — each requires its own ADR/egress/licence review); (C) hybrid A + B. Do not add any dependency in this task.
- [ ] Build a retrieval eval: ≥ 40 questions with expected source recordings/segments over a synthetic library of ≥ 30 recordings (fictional data; reuse PRF-09/TPL synthetic transcripts), covering exact-term, paraphrase, multi-recording, date-bounded ("last week"), and unanswerable questions. Measure recall@k and answer-support rate for each option on the host.
- [ ] Context budget: compute, from `docs/…`/`vv-llm-inference` KV maths and the tier `n_ctx` values, how many retrieved passages fit per tier with 3B (ASK-01), including prompt overhead and reserved answer tokens; state the fallback when the question needs more than fits (top-k cut vs map-reduce).
- [ ] Residency: define the sequence that respects "never hold STT and LLM models in memory together" (ask runs only when no transcription is in progress, or queues behind it) and the `ModelResidency.acquire` use.
- [ ] Privacy: stored chat history (yes/no, how long, where, encrypted with the existing DB key), deletion cascade with recordings (SEC-04), exclusion from backups, no question or answer text in logs, and behaviour when app lock is on (SEC-03).
- [ ] Answer contract: every claim cites recording id + timestamp (clickable); "I couldn't find that in your notes" when retrieval support is below the measured threshold; no use of the model's world knowledge for facts about the user's life.
- [ ] Write `docs/adr/ADR-ASK-02-retrieval.md` (Proposed) with options, weighted criteria and the measured evidence.

## Acceptance Criteria
- ADR exists with weighted criteria and a measured table (recall@k, answer-support rate, latency, RAM) for every compared option, produced by a committed, re-runnable script (artifact).
- The chosen option meets recall@5 ≥ 80% on the eval set **or** the ADR states the achieved number and why it is still acceptable; the threshold is fixed in the ADR before the run.
- The ADR gives the per-tier passage budget with the arithmetic, and the residency sequence with the failure behaviour when memory is short.
- The ADR specifies chat-history storage, deletion and logging rules, each traceable to SEC-01/SEC-03/SEC-04 and `vv-privacy-security`.
- If the chosen option needs a new model or dependency, the ADR lists the follow-up task IDs needed (catalog, egress, licence) and ASK-03 is marked blocked on them.

## Notes
- English only. Retrieval must work with the 1B model's tier fallback state defined (e.g. "Ask requires the 3B model" screen), decided here and implemented in ASK-04.
