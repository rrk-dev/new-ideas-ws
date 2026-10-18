# ASK-02 retrieval eval — option A (FTS5 BM25 over `search_index`)

Date: 2026-10-17 · host: Darwin arm64, Python 3.11.0 · SQLite 3.54.0 · commit `1172655` · library 33 recordings, 44 questions · reproduce: `python3 tools/bench/ask/retrieval_eval.py`

Threshold (pre-registered in ADR-ASK-02): segment recall@5 ≥ 80%. **Achieved: 59.3% → FAIL.**

## Option A, all answerable questions

| Metric | Value |
|---|---|
| seg_recall@1 | 28.2% |
| seg_recall@3 | 48.6% |
| seg_recall@5 | 59.3% |
| seg_recall@10 | 80.6% |
| rec_recall@5 | 91.7% |
| mrr | 0.474 |
| answer_support_rate | 50.0% |
| wrongly_abstained | 22.2% |
| correct abstention (unanswerable, n=8) | 62.5% |
| false-answer rate (unanswerable) | 37.5% (U01, U02, U04) |

## By question type

| Type | n | seg@1 | seg@3 | seg@5 | seg@10 | rec@5 | MRR | support | wrongly abstained |
|---|---|---|---|---|---|---|---|---|---|
| exact | 12 | 33.3% | 58.3% | 75.0% | 91.7% | 100.0% | 0.49 | 75.0% | 0.0% |
| paraphrase | 10 | 20.0% | 20.0% | 30.0% | 70.0% | 100.0% | 0.28 | 10.0% | 40.0% |
| multi | 8 | 27.1% | 68.8% | 79.2% | 87.5% | 93.8% | 0.72 | 75.0% | 12.5% |
| date | 6 | 33.3% | 50.0% | 50.0% | 66.7% | 58.3% | 0.44 | 33.3% | 50.0% |

## Questions that missed gold segments at k=5

| id | type | stems | seg@5 | support | abstains |
|---|---|---|---|---|---|
| E02 | exact | store sold litware headphon | 0.0% | 0.50 | no |
| E09 | exact | competitor wingtip logistic look | 0.0% | 0.50 | no |
| E11 | exact | chloe project fail | 0.0% | 1.00 | no |
| P01 | paraphrase | pay coffee mill | 0.0% | 0.33 | yes |
| P02 | paraphrase | guarantee wash machine | 0.0% | 0.67 | no |
| P03 | paraphrase | agre mov product release | 0.0% | 0.50 | no |
| P04 | paraphrase | cover onboard guide while nadia away | 0.0% | 0.50 | no |
| P05 | paraphrase | pro using plain fil instead database mobile | 0.0% | 0.57 | no |
| P06 | paraphrase | team conclude microservic | 0.0% | 0.67 | no |
| P07 | paraphrase | assignment student economic | 100.0% | 0.33 | yes |
| P08 | paraphrase | worri proseware retail team security | 100.0% | 0.40 | yes |
| P10 | paraphrase | question pilot begin answer | 0.0% | 0.25 | yes |
| M01 | multi | advice interviewe give people start | 0.0% | 0.80 | no |
| M05 | multi | sal call involv proseware retail | 33.3% | 0.40 | yes |
| D01 | date | record warranti | 0.0% | 0.50 | no |
| D02 | date | decision engineer discussion | 0.0% | 0.33 | yes |
| D03 | date | lecture cover | 0.0% | 0.00 | yes |
| D04 | date | security concern call | 100.0% | 0.33 | yes |

## Latency and index size (host, in-memory SQLite; not device figures)

| Recordings | Index rows | DB MiB | Build s | Query median ms | Query p95 ms | Process max RSS MiB |
|---|---|---|---|---|---|---|
| 33 | 359 | 0.18 | 0.01 | 0.09 | 0.22 | 21.4 |
| 1023 | 11129 | 4.11 | 0.2 | 1.14 | 3.58 | 27.4 |
| 9999 | 108777 | 36.49 | 1.81 | 8.34 | 17.34 | 71.9 |

Scaled rows replicate the 33 recordings under new ids (identical text), so they measure index size and BM25 cost, not relevance. RSS is the whole Python process high-water mark.

## Options B and C

**Unmeasured.** Both need an embedding model and a vector store, which this task may not add (no dependency, no catalog model). No recall, latency or RAM number is claimed for them. LLM query rewriting for option A is also **Unmeasured** (no local 3B runner here).

## Context budget arithmetic (planning; see ADR-ASK-02)

Passage budget = n_ctx − answer reserve 512 − prompt overhead 450 (assumed) − question 64 − safety 64. Tokens per word 1.4 and 24 header tokens per passage are assumptions; mean words per eval segment = 12.0. RSS estimate = measured 3718 MiB at n_ctx 4096 (ASK-01) + extra f16 KV (112 KiB/token for the 3B).

| Passage size | Model | Tier | n_ctx | Passage budget (tok) | Single segments fit | ±1-neighbour windows fit | Extra KV MiB | 3B RSS est. MiB | Prefill s for a full budget (3B host CPU) |
|---|---|---|---|---|---|---|---|---|---|
| eval mean (41 / 74 tok) | 3B | High (chosen) | 6144 | 5054 | 124 | 68 | 224 | 3942 | 35–50 |
| eval mean (41 / 74 tok) | 3B | High (max) | 8192 | 7102 | 174 | 95 | 448 | 4166 | 49–70 |
| eval mean (41 / 74 tok) | 1B | Low/Mid fallback | 4096 | 3006 | 73 | 40 | 0 | n/a | n/a |
| eval mean (41 / 74 tok) | 1B | High | 8192 | 7102 | 174 | 95 | 128 | n/a | n/a |
| 30 s Whisper segment (assumed 75 words) (129 / 339 tok) | 3B | High (chosen) | 6144 | 5054 | 39 | 14 | 224 | 3942 | 35–50 |
| 30 s Whisper segment (assumed 75 words) (129 / 339 tok) | 3B | High (max) | 8192 | 7102 | 55 | 20 | 448 | 4166 | 49–70 |
| 30 s Whisper segment (assumed 75 words) (129 / 339 tok) | 1B | Low/Mid fallback | 4096 | 3006 | 23 | 8 | 0 | n/a | n/a |
| 30 s Whisper segment (assumed 75 words) (129 / 339 tok) | 1B | High | 8192 | 7102 | 55 | 20 | 128 | n/a | n/a |
