# Extraction eval — `engineering` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `279469c` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 184 s incl. model load + Dart compile · peak RSS: 1154 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 93.3% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 19.3% |
| Prefill tok/s (median) | 4445 |
| Decode tok/s (median) | 93.0 |
| Latency per case (median / max) | 5.1 s / 11.6 s |
| Prompt tokens (median / max) | 1022 / 1116 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 17.8% | 72.2% | 28.6% | 36 | 146 | – |
| api_designs | 1.5% | 22.2% | 2.9% | 9 | 130 | – |
| tradeoffs | 15.5% | 71.9% | 25.6% | 32 | 148 | – |
| decisions | 8.3% | 50.0% | 14.2% | 26 | 157 | – |
| todos | 40.7% | 34.4% | 37.3% | 32 | 27 | owner 72.7% |
| open_questions | 1.5% | 33.3% | 2.9% | 9 | 200 | – |

Prose fields (token-set similarity to the reference, informational): title 73.9%, context 52.3%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 34.4% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 71.9% | ✅ |
| schema_valid | ≥ 99.0% | 93.3% | ❌ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 1026 | 10.6 | concepts 1/1/20, api_designs 0/0/3, tradeoffs 2/2/10, decisions 1/1/20, todos 0/1/1, open_questions 0/1/20 |
| engineering-002 | ✅ | 1026 | 3.8 | concepts 0/0/4, api_designs 0/1/4, tradeoffs 0/0/4, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-003 | ✅ | 1065 | 9.6 | concepts 2/2/20, api_designs 0/0/10, tradeoffs 0/2/4, decisions 1/1/9, open_questions 0/0/20 |
| engineering-004 | ✅ | 999 | 10.5 | concepts 0/0/7, api_designs 0/0/6, tradeoffs 2/2/6, decisions 0/0/20, todos 0/0/1, open_questions 0/1/20 |
| engineering-005 | ✅ | 987 | 4.3 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 0/0/10, decisions 0/0/1, open_questions 0/0/1 |
| engineering-006 | ✅ | 1064 | 5.4 | concepts 2/2/4, api_designs 0/0/10, decisions 0/1/0, todos 0/1/0, open_questions 0/1/0 |
| engineering-007 | ✅ | 1007 | 7.4 | concepts 1/1/6, api_designs 1/1/6, tradeoffs 2/2/10, decisions 1/1/5, todos 0/1/1, open_questions 0/0/20 |
| engineering-008 | ✅ | 992 | 3.9 | concepts 0/0/4, api_designs 0/0/4, tradeoffs 0/0/4, decisions 0/0/4, todos 1/3/1, open_questions 0/0/3 |
| engineering-009 | ✅ | 1051 | 4.3 | concepts 2/2/4, api_designs 0/0/4, tradeoffs 1/1/4, open_questions 1/1/2 |
| engineering-010 | ✅ | 1010 | 5.5 | concepts 1/1/4, api_designs 0/0/10, tradeoffs 0/0/9, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-011 | ✅ | 1024 | 2.3 | concepts 1/1/2, api_designs 0/1/1, tradeoffs 2/2/3, decisions 1/1/2, open_questions 0/0/1 |
| engineering-012 | ❌ | 1022 | 10.8 | concepts 0/3/0, open_questions 0/1/0 |
| engineering-013 | ❌ | 1038 | 11.6 | concepts 0/2/0, tradeoffs 0/1/0, decisions 0/1/0, todos 0/1/0 |
| engineering-014 | ✅ | 1031 | 4.3 | concepts 2/2/5, api_designs 1/1/4, tradeoffs 2/2/5, decisions 0/1/3, open_questions 0/0/2 |
| engineering-015 | ✅ | 994 | 2.8 | concepts 1/1/3, api_designs 0/0/2, tradeoffs 0/0/3, decisions 0/1/1, todos 0/2/1, open_questions 1/1/2 |
| engineering-016 | ✅ | 1015 | 6.4 | concepts 1/1/4, api_designs 0/0/10, tradeoffs 2/2/3, decisions 0/1/3, open_questions 0/0/3 |
| engineering-017 | ✅ | 1116 | 5.4 | concepts 1/3/7, api_designs 0/1/1, tradeoffs 0/1/6, decisions 0/2/5, todos 0/2/1, open_questions 0/1/8 |
| engineering-018 | ✅ | 1008 | 8.8 | concepts 0/1/4, api_designs 0/0/6, tradeoffs 0/0/10, decisions 1/1/3, todos 0/1/1, open_questions 0/0/20 |
| engineering-019 | ✅ | 1056 | 2.4 | concepts 2/2/3, api_designs 0/0/1, tradeoffs 2/2/3, decisions 1/1/2, todos 0/1/1, open_questions 1/1/2 |
| engineering-020 | ✅ | 1022 | 7.9 | concepts 0/1/7, api_designs 0/1/10, tradeoffs 0/0/6, decisions 0/1/20, todos 0/1/1, open_questions 0/0/1 |
| engineering-021 | ✅ | 1017 | 2.5 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 1/1/4, decisions 0/1/2, open_questions 0/0/1 |
| engineering-022 | ✅ | 957 | 4.5 | concepts 0/0/2, api_designs 0/0/3, tradeoffs 0/0/10, decisions 0/0/1, todos 0/0/1, open_questions 0/0/1 |
| engineering-023 | ✅ | 1013 | 2.4 | concepts 1/1/3, api_designs 0/0/2, tradeoffs 1/1/2, open_questions 0/0/2 |
| engineering-024 | ✅ | 1039 | 9.8 | concepts 1/1/3, api_designs 0/0/10, tradeoffs 1/2/4, decisions 0/1/20, todos 0/2/1, open_questions 0/0/20 |
| engineering-025 | ✅ | 1018 | 7.8 | concepts 0/0/3, api_designs 0/1/4, tradeoffs 0/2/5, decisions 1/1/4, todos 0/1/1, open_questions 0/0/20 |
| engineering-026 | ✅ | 1006 | 2.9 | concepts 2/2/5, api_designs 0/0/3, tradeoffs 0/1/3, decisions 0/1/1, open_questions 0/0/1 |
| engineering-027 | ✅ | 1038 | 9.9 | concepts 2/2/5, api_designs 0/0/4, tradeoffs 1/1/5, decisions 1/1/20, todos 0/1/1, open_questions 0/1/20 |
| engineering-028 | ✅ | 996 | 3.6 | concepts 0/0/4, api_designs 0/0/2, tradeoffs 1/2/6, decisions 1/1/3, todos 0/1/1, open_questions 0/0/3 |
| engineering-029 | ✅ | 1025 | 4.8 | concepts 0/1/5, api_designs 0/1/5, tradeoffs 1/1/5, decisions 1/1/2, open_questions 0/0/3 |
| engineering-030 | ✅ | 1029 | 3.3 | concepts 1/1/2, api_designs 0/1/3, tradeoffs 0/0/2, decisions 1/1/2, todos 0/1/1, open_questions 0/0/2 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
