# ADR-ASK-02 — Ask-your-notes retrieval: FTS5 vs embeddings, context budget, residency, privacy

- **Status:** Proposed
- **Date:** 2026-10-17
- **Task:** ASK-02
- **Deciders:** Copilot CLI (implementer); pending independent verifier + human (product questions at the end)
- **Supersedes:** —

## Context

Phase 2 adds "Ask": the user asks a question in English and Lumen answers from their own
library, citing recordings, fully on-device (AGENTS.md: no cloud, no user content leaves the
device). Ask is a Free feature; no Pro gating is enforced by this decision.

Hard constraints that shape the options:

- **No new dependency in this task.** A new model, native library or pub package needs its own
  ADR, egress review (SEC-01/`check_egress.sh`, `lib/core/network` allowlist) and licence review
  (SEC-05).
- **Memory:** STT and LLM are never resident together (`ModelResidency`, LLM-07).
- **Models:** the answer model is Llama-3.2-3B-Instruct Q4_K_M (ASK-01, PR #77, pending merge).
  From `tools/bench/results/2026-10-17-ask01-1b-vs-3b.md` (branch
  `origin/task/ASK-01-llama-3b-catalog-model`, host CPU, n_ctx 4096): peak RSS **3718 MiB**,
  decode 21–33 tok/s (about half the 1B's 46–70), prefill 102–145 tok/s, load ≈ 11 s (1B ≈ 5 s).
  It is recommended for the **High tier only** (`min_ram_mb` 7168; High RSS budget 4200 MiB,
  Mid 2800 MiB). The 1B stays the default extraction model.
- **Index that exists today:** `search_index`, an FTS5 table (`app/lib/core/db/tables/search.drift`,
  tokenizer `unicode61 remove_diacritics 2`) with rows of kind `title` (title + tags),
  `transcript` (one row per transcript segment, rowid = −segment id) and `extraction` (every
  string value of the newest extraction), kept in sync by triggers. It has no date column; the
  recording date lives in `recordings`.
- Library sizes: a few hundred recordings is typical; the stress target is thousands.

## Options

1. **A — FTS5 BM25 over `search_index`**, with a query built from the question (stop-word
   removal, prefix terms, deterministic date filter parsed in Dart) and optionally rewritten by
   the LLM. No new model or dependency.
2. **B — On-device embedding model + vector store.** Needs a new catalog model, a new native or
   Dart dependency (or sqlite vector extension) and a new download. Each needs its own
   ADR/egress/licence review.
3. **C — Hybrid A + B** (reciprocal-rank fusion of BM25 and vector hits). Same new
   requirements as B.

## Criteria (weights fixed before measuring)

| Criterion | Weight |
|---|---|
| Retrieval quality on the eval set (segment recall@5, answer-support rate, correct abstention) | 30% |
| No new dependency / model / network surface (privacy, SEC-01/SEC-05 review cost) | 20% |
| Latency and RAM on target devices (host measured, device pending) | 20% |
| Integration effort (reuses existing index, deletion cascade, triggers) | 15% |
| Testability and maintenance | 15% |

## Pre-registered protocol and thresholds (written before the first run)

These were committed before `tools/bench/ask/retrieval_eval.py` was run for the first time.

- **Corpus:** 33 fictional recordings from the PRF-09 synthetic transcripts
  (`tools/bench/eval/{meeting,warranty,engineering}/*-001..006`,
  `{lecture,sales_call,interview}/*-001..005`) with dates assigned in
  `tools/bench/ask/library.json`; fixed "today" 2026-03-30. Indexed with the same DDL as
  `search.drift` (the script reads it from the file) and the same three row kinds.
- **Questions:** `tools/bench/ask/questions.json`, 44 English questions: 12 exact-term, 10
  paraphrase, 8 multi-recording, 6 date-bounded, 8 unanswerable. Each answerable question lists
  gold evidence items (recording id + accepted transcript timestamps). Gold was written from the
  transcripts before running.
- **Retrieval unit (passage):** one FTS5 row; hits of kind `title`/`extraction` count for
  recording recall but cannot satisfy a timestamped citation.
- **Primary metric: segment recall@5** = mean over answerable questions of the fraction of gold
  items whose transcript segment is in the top 5 passages. Also reported: recall@1/3/10,
  recording-level recall@5, MRR.
- **Threshold: the chosen option must reach segment recall@5 ≥ 80%.** If it does not, the ADR
  states the achieved number and why it is still acceptable (or chooses the option that does).
- **Answer-support rate** = share of answerable questions whose gold items are all in the top 5
  *and* that pass the abstention gate.
- **Abstention gate (fixed):** content terms = question tokens minus stop words and date words;
  a term matches a passage token when the token starts with the term's stem (suffixes `ing`,
  `ed`, `es`, `s` stripped, minimum stem length 3). The system answers only if some top-5
  passage matches ≥ 50% of the content terms; otherwise it says "I couldn't find that in your
  notes". **Correct-abstention rate** on unanswerable questions is reported with the
  false-answer rate.
- **Date filter:** `yesterday`, `last week`, `this week`, `last <weekday>`, `on <weekday>`,
  `in <month>` are parsed deterministically in Dart (not by the LLM) and applied as a
  `recordings` date filter before BM25.
- **Query rewriting by the LLM** is not run: no local runner for the 3B model is available in
  this environment. The measured option A is the deterministic query builder without LLM
  rewrite; the rewrite gain is reported as **Unmeasured**.
- **Options B and C** need an embedding model that this task may not add; they are reported
  **Unmeasured** (analytical estimates are labelled as such, never as measurements).
- **Latency/RAM for A:** query latency (median/p95) and in-memory index size at 33, ~1 000 and
  ~10 000 recordings (the corpus replicated with new ids), host Python `sqlite3` 3.54.0 — not a
  device figure.
