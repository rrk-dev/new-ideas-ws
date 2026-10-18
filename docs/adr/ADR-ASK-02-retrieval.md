# ADR-ASK-02 — Ask-your-notes retrieval: FTS5 vs embeddings, context budget, residency, privacy

- **Status:** Accepted for the product decisions (human, 2026-10-17); the retrieval choice stays conditional on the ASK-03 end-to-end eval (see Decision)
- **Date:** 2026-10-17
- **Task:** ASK-02
- **Deciders:** Copilot CLI (implementer); human (product decisions, 2026-10-17); independent verifier pending
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

## Evidence

Raw data and script: `tools/bench/ask/retrieval_eval.py` (re-runnable, stdlib only),
`tools/bench/ask/library.json`, `tools/bench/ask/questions.json`; results
`tools/bench/results/2026-10-17-ask02-retrieval.{md,json}` (per-question rankings in the JSON).
Environment: Apple M3 Pro, macOS arm64, Python 3.11.0, SQLite 3.54.0 (FTS5), run at commit
`1172655` plus the eval files. The corpus' "extraction" rows are the hand-written `expected.json`
of each case (an ideal extraction), so extraction-row hits are optimistic relative to real LLM
output.

| Metric | A: FTS5 BM25 (no LLM rewrite) | B: embeddings | C: hybrid |
|---|---|---|---|
| Segment recall@5 (primary, threshold ≥ 80%) | **59.3% — below threshold** | Unmeasured | Unmeasured |
| Segment recall@1 / @3 / @10 | 28.2% / 48.6% / 80.6% | Unmeasured | Unmeasured |
| Recording recall@5 | 91.7% | Unmeasured | Unmeasured |
| MRR | 0.474 | Unmeasured | Unmeasured |
| Answer-support rate (gold in top 5 and gate passes) | 50.0% | Unmeasured | Unmeasured |
| Correct abstention / false-answer (unanswerable, n = 8) | 62.5% / 37.5% (U01, U02, U04) | Unmeasured | Unmeasured |
| Query latency, host, median / p95 (33 → 1 023 → 9 999 recordings) | 0.09/0.22 → 1.14/3.58 → 8.34/17.34 ms | Unmeasured | Unmeasured |
| Index size, host (same scales) | 0.18 → 4.1 → 36.5 MiB (existing table, no extra) | Unmeasured | Unmeasured |
| Process RSS high-water, host | 21 → 27 → 72 MiB | Unmeasured | Unmeasured |
| New model / dependency / download | none | yes (new catalog model + runtime or extension) | yes |

By question type (segment recall@5): exact 75.0%, paraphrase **30.0%**, multi-recording 79.2%,
date-bounded 50.0%. At k = 10 the exact/multi types reach 91.7% / 87.5%, paraphrase 70.0%.

What the numbers say:

- BM25 finds the right *recording* in the top 5 for 91.7% of gold items but the right *segment*
  for only 59.3%: in short synthetic recordings the extraction/title rows and sibling segments
  outrank the answer segment. Paraphrases fail because FTS5 only matches words that occur
  ("guarantee" vs "warranty", "agreed" vs "decided").
- Date-bounded questions that name no content word ("what did the lecture on Friday cover")
  have no usable terms after stop-word removal; they need a "list the recordings in range"
  path in ASK-03, not BM25.
- The pre-registered term-coverage abstention gate is too crude: it wrongly abstains on 22.2%
  of answerable questions and lets 3 of 8 unanswerable ones through (they share two terms with a
  real passage, e.g. "vendor contract"). It must not be the only guard.
- Latency is not a concern: ≤ 17 ms p95 at ~10 000 recordings on the host.
- **Unmeasured:** LLM query rewriting (the main expected fix for paraphrase), options B and C
  (no embedding model may be added in this task), and everything on a device. Analytical note
  only, not a measurement: a 384-dimension float32 vector costs 1.5 KiB per passage, so
  100 000 passages would add about 147 MiB of vectors on top of the model — the real figure
  depends on the unchosen model and is for the B/C spike.

Weighted view (weights above). Quality is only known for A; B/C are not scored on it.

| Criterion (weight) | A | B / C |
|---|---|---|
| Retrieval quality (30%) | Measured: misses the 80% bar at k = 5 (59.3%), 80.6% at k = 10 | Unmeasured; paraphrase is where an embedding model is expected to help |
| No new dependency/model (20%) | Best: nothing new | New model, runtime/extension, download, egress and licence review |
| Latency/RAM (20%) | Measured on host; negligible | Unmeasured; extra resident model or a second model load |
| Integration (15%) | Best: table, triggers, SEC-04 purge already exist | New store plus a re-embed on every transcript edit |
| Testability (15%) | Deterministic, runs in CI without a model | Needs a model in CI |

## Decision

**Choose A (FTS5 BM25 over the existing `search_index`) for v1, with a larger candidate set
than 5, and run the end-to-end eval in ASK-03 before this ADR becomes Accepted.** Status stays
*Proposed*. The decision rests on the hard constraints (no new dependency or download for Ask v1)
and on A being the only option measured; it is **not** a claim that A passes the bar.

**Achieved vs threshold, stated plainly:** segment recall@5 is **59.3%, below the 80%
threshold** fixed before the run. Why it is still acceptable as the v1 baseline: (1) the 3B
context budget below fits well over 10 passages, so the generator is not limited to the top 5;
at k = 10 segment recall is 80.6% and exact/multi-recording questions are 91.7% / 87.5%;
(2) recording recall@5 is 91.7%, so neighbour expansion (below) recovers many near misses.
This is an argument made after seeing the data, so ASK-03 must re-measure on the full
pipeline and may not rely on it. If ASK-03's end-to-end eval with the 3B (LLM query rewrite, k = 10) does
not reach 80% segment recall@10 and its citation/refusal targets, the follow-up spike for
B/C (below) becomes mandatory before Ask ships.

### Retrieval design for ASK-03

- Query builder in Dart: stop-word removal, stem-prefix terms, `OR` of terms, BM25 ranking;
  optional LLM rewrite step (adds synonyms and the document's vocabulary, e.g. "guarantee" →
  "warranty") that is **Unmeasured** here and must be evaluated in ASK-03.
- Dates, profile, tag and `recordingId` scope are parsed/applied deterministically in Dart as
  SQL filters (as in the eval); the LLM is never asked to compute dates. A per-recording Ask
  filters to its `recordingId` before ranking. Questions with no content terms but a date or
  scope ("what did I record yesterday") use a "recordings in range" path instead of BM25.
- Passages are transcript segments (the index unit) with `title`/`extraction` rows as
  supporting context. Candidate set k = 10; the top 3 are expanded with ±1 neighbouring
  segment so a citation still points at one timestamped segment.

## Context budget per tier

Formula (same as `TokenBudgetPlanner`): `passage budget = n_ctx − answer reserve (512) −
prompt overhead (450, assumed: system + citation contract + answer schema) − question (64) −
safety (64)`. KV memory uses the `vv-llm-inference` figure of 112 KiB per token for the 3B at f16.
Exact counts come from `vv_llm_count_tokens` in ASK-03; the token-per-word and header costs are
planning assumptions (1.4 tokens/word, 24 header tokens). From the results file:

| Model / tier | n_ctx | Passage budget | Segments that fit (12-word eval mean / 75-word Whisper segment) | Extra KV vs 4096 | 3B RSS estimate |
|---|---|---|---|---|---|
| 3B, High — **chosen** | 6144 | 5 054 tok | 124 / 39 | +224 MiB | 3 942 MiB |
| 3B, High — maximum | 8192 | 7 102 tok | 174 / 55 | +448 MiB | 4 166 MiB |
| 1B, Low/Mid — fallback | 4096 | 3 006 tok | 73 / 23 | 0 | not applicable |

- RSS estimate = measured 3 718 MiB peak at n_ctx 4096 (ASK-01) + extra KV; it is an upper bound
  (untouched KV pages are not resident). The High RSS budget is 4 200 MiB: at 8192 the headroom
  is 34 MiB, at 6144 it is 258 MiB. **Ask therefore runs the 3B at n_ctx 6144.**
- Memory is not the binding limit, **time is**. Prefill of a full 5 054-token budget would take
  35–50 s on the host CPU at the 3B's measured 102–145 tok/s. Ask therefore sends far less
  than the budget: top-10 single segments plus ±1 neighbours for the top 3 ≈ 10 × 129 +
  3 × 2 × 129 ≈ 2 100 tokens at 75 words per segment (≈ 600 tokens with the 12-word eval
  mean), i.e. **≈ 15–21 s prefill + 250 answer tokens at 21–33 tok/s ≈ 8–12 s decode** on the
  host CPU. These are arithmetic from ASK-01's host numbers, not device measurements; the
  device time-to-first-answer is owned by ASK-03's per-tier budget row.
- **Fallback when the question needs more than fits** (e.g. "list every call where…" with > 10
  relevant passages): v1 uses a **top-k cut** and says so ("Based on the 10 best matches; narrow
  by date or recording to see more"), and the UI offers a date/recording filter. **Map-reduce
  (LLM-06) is not used in v1**: each map call is a full 3B prefill (≈ 15–20 s), so N chunks
  cost N × that, and the LLM-06 chunker is built for one transcript, not for passages from
  many recordings. Revisit after the device numbers.

## Residency sequence and failure behaviour

1. **Ask never preempts a pipeline job.** If a transcription/extraction job is running or
   queued-and-active, Ask shows "Waiting for processing to finish…" and queues behind it
   (retrieval, which is plain SQL, can still run and show the cited passages immediately).
2. When the pipeline is idle: `ModelResidency.acquire(ResidentModel.llm)` — this awaits the
   unload of STT if it is resident (LLM-07). If it throws `ModelResidencyException` the LLM
   is **not** loaded; Ask shows the retrieved passages with citations and "Couldn't free enough
   memory to write an answer — try again after the current job" (retryable, mapped to the
   existing `OutOfMemoryFailure`).
3. Pre-load gate: `available ≥ estimate × 1.2` with the n_ctx 6144 estimate from the table. If
   it fails, the same retrieval-only result is shown; Ask never retries with a smaller model
   and never calls the cloud.
4. After answering, the LLM stays resident for a short idle window (a follow-up question skips
   the ≈ 11 s load) then `releaseAll`. When the pipeline later needs STT it calls
   `acquire(ResidentModel.stt)`; an in-flight Ask is cancelled at the next token, its partial
   answer is discarded, and the user can ask again.
5. A memory-pressure signal cancels Ask first (LLM-07 behaviour), unloads the LLM, and shows the
   retrieval-only result.

## 1B-model fallback ("Ask requires the 3B model")

The 3B is recommended for the High tier only (ASK-01: `min_ram_mb` 7168). Decision for ASK-04:

- **3B installed on a High-tier device:** Ask is available.
- **High-tier device, 3B not installed:** a full-screen "Ask requires the 3B model" state with
  the download size (≈ 2.0 GB, from the ASK-01 catalog entry) and a button to the Models screen;
  the download is the normal, user-initiated model download (MDL-02).
- **Mid/Low-tier device (or the 1B is the only model):** an "Ask isn't available on this device"
  state explaining why. The 1B is **not** used for answering in v1: it was not evaluated for
  grounded question answering and the ASK-01 results show it hallucinates more on some profiles
  (e.g. warranty 34.4% vs 13.6%). Normal library full-text search (APP-02) stays available on
  every tier. Mid-tier support is revisited when the ASK-01 device rows pass.
- Both states are typed `Failure`s in ASK-03 (no crash, no cloud fallback).

## Answer contract

- Every claim cites `recording id + timestamp` of a retrieved passage; citations are clickable
  (open the recording at that time). A citation not in the retrieved set is dropped (ASK-03/AC2).
- Output is grammar-constrained (LLM-05 path): `{found, answer, citations[{recording_id, t}]}`.
- If retrieval is empty, or the model sets `found = false`, or no valid citation survives, the
  answer is **"I couldn't find that in your notes."** The pre-registered term-coverage gate
  (≥ 50% of content terms in a top-5 passage) is measured but weak (22.2% wrongly abstained, 37.5%
  false answers), so it is only used to short-circuit when retrieval returns nothing; the
  refusal decision otherwise belongs to `found` plus citation validation, and ASK-03's
  eval (unanswerable refusal ≥ 90%) is the gate.
- System prompt: answer only from the supplied passages; passages are data (inside a delimited
  block) and instructions in them are ignored; no use of world knowledge for facts about the
  user's life; English only.

## Privacy and storage rules

Each rule is traceable to the named task/skill (`vv-privacy-security`).

| Rule | Decision | Source |
|---|---|---|
| Store chat history? | **Yes, optional.** Threads and messages are stored so a conversation survives app restarts; a setting "Save Ask history" (default on) can turn it off, in which case nothing is persisted. Retention default is **30 days** after the last message (product question 3), plus "Delete one" and "Delete all". | SEC-04 retention model |
| Where | The existing encrypted database (sqlite3mc, key `db.v1` from `KeyVault`); new tables via a drift migration (ASK-03). No separate file, no plain-text cache. | SEC-01 |
| Citations | Stored as FK references to the recording/segment, never as copies of transcript text; the answer text is stored. | SEC-04 |
| Deletion cascade | Deleting a recording deletes every stored message that cites it (FK `ON DELETE CASCADE` through the citation table; a multi-recording answer is deleted whole). Transcript expiry with audio kept (`RecordingPurger` scope `transcripts`) purges answers, citations and cached passages derived from that recording too. `secure_delete = ON` applies. "Delete all data" removes the new tables automatically (it iterates `db.allTables`) and its key rotation shreds the old data. ASK-03/AC4 and AC8 test this. | SEC-04 |
| Backups | The database already lives under `vv/` excluded from iOS/Android backups; Ask adds no file outside it. | SEC-01 |
| Logging | No question, answer, passage or recording title at INFO or above: log only counts, durations, token counts, error types (`ASK-03/AC5`). | `vv-privacy-security`, FND-07 |
| Network | None: no egress call for Ask; `check_egress.sh` must show no new host. The 3B download uses the existing model gateway entry. | SEC-01, `lib/core/network` |
| App lock on | The Ask screens sit behind the SEC-03 gate. On lock: cancel generation, drop the in-memory conversation, release the LLM; history stays encrypted at rest. No answer text in notifications or the app-switcher snapshot (already content-free). | SEC-03 |

## Consequences

- Positive: Ask v1 needs no new model, dependency, download or egress host; the index, its sync
  triggers and SEC-04 deletion already exist; latency is negligible.
- Negative / risks: paraphrase recall is poor without rewriting (30% at k = 5), the abstention
  gate is crude, date-only questions need a separate path, and the 3B's ≈ 15–30 s answer time
  and High-tier-only availability limit the audience. Mitigation: ASK-03's end-to-end eval
  decides; B/C spike is the escape hatch.
- **New model/dependency needed by the chosen option: no**, so ASK-03 is **not** blocked by this
  ADR (it stays dependent on ASK-01's merge). Only if the ASK-03 eval fails and B/C is chosen
  would a new model/runtime be needed. The follow-up chain to propose then (IDs to be
  allocated; nothing is added now): ASK-05 spike for B/C with an embedding model (ADR +
  measurements on the ASK-02 set), a catalog task for the embedding model (MDL), an egress
  and licence review task (SEC-01/SEC-05), a sqlite-vector/runtime dependency review task, and
  re-blocking ASK-03 on them.
- Follow-up tasks: see the task file's `## Follow-ups`.

## ASK-03 end-to-end outcome (measured 2026-10-17)

Host (Apple Silicon CPU path of the host bridge), 3B Q4_K_M, n_ctx 6144, greedy,
grammar-constrained; 44 questions, 33 recordings. Reports:
`tools/bench/results/2026-10-17-ask03-eval.md` (final engine),
`2026-10-17-ask03-eval-run1.md` (first engine), `-run2.md` (adds the rewrite arm) and
`-run3.md`. Four runs were made; all are committed, none is hidden.

| Run (engine change) | Correctness (≥70) | Citation precision (≥90, gate) | Refused (≥90, gate) | Hallucination (≤15) | Seg recall@10 (≥80, gate) |
|---|---|---|---|---|---|
| 1 first engine | 44.4% | 85.7% | 75.0% | 16.7% | 88.9% |
| 2 + date fallback, `ies` stem, `found` last in schema | 77.8% | 82.1% | 75.0% | 16.7% | 91.7% |
| 2 rewrite arm (same engine) | 72.2% | 84.2% | 87.5% | 13.9% | 80.6% |
| 3 + stricter system prompt | 83.3% | 87.9% | 75.0% | 13.9% | 91.7% |
| 4 final: + deterministic grounding check (drop non-overlapping citations; names in the question must appear in the cited recordings) | 72.2% | 86.0% | 87.5% | 13.9% | 91.7% |

- **Retrieval gate met:** segment recall@10 is 91.7% on the passages given to the model, so FTS5 with k = 10 and
  neighbour expansion stands and **no ASK-05 embedding spike is required** for retrieval.
- **LLM query rewrite: do not adopt.** It lowered recall@10 (91.7% → 80.6%) and paraphrase
  correctness; the pre-registered rule needs a recall gain. It was only measured on the run-2 engine.
- **Two ASK-03 gates are still NOT met in the final run:** citation precision 86.0% (< 90%; 43 of
  50 citations on a gold recording) and unanswerable refusal 87.5% (< 90%; U02 "Who approved the
  vendor contract?" is still answered "Aisha" from an unrelated meeting). The grounding check fixed
  U04 but cost multi-recording correctness (62.5% → 25.0%); correctness 72.2% is above its 70% target
  with little margin. The 3B follows lexical overlap. Options are listed in the ASK-03 follow-ups.
- The status of the retrieval choice therefore stays "Accepted for FTS5 k = 10 retrieval"; the
  answer-generation quality gates are open.

## Product decisions (human, 2026-10-17)

1. **Ask is Free and uses the 3B.** No Pro tier is enforced now, so the "Free is capped at the 1B"
   rule does not apply to Ask; ASK-04 does not gate on `FeatureGate`/LIC-05.
   `PRODUCT-DECISION` markers record this in code; revisit when a Pro tier is enforced.
2. **No 1B Ask:** Mid/Low tiers show "Ask isn't available on this device".
3. **Chat history is saved by default** with a 30-day expiry, a user-visible clear-all and
   per-chat delete.
