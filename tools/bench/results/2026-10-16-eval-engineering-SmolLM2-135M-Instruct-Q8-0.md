# Extraction eval — `engineering` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-16 · host: Darwin arm64 · backend: gpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `ebf4ff7` · llama.cpp `ebf4ff7` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 147 s incl. model load + Dart compile · peak RSS: 527 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 66.7% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 9.1% |
| Prefill tok/s (median) | 24625 |
| Decode tok/s (median) | 113.4 |
| Latency per case (median / max) | 6.7 s / 1030.4 s |
| Prompt tokens (median / max) | 898 / 1014 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 19.4% | 16.7% | 17.9% | 36 | 31 | – |
| api_designs | 0.0% | 0.0% | 0.0% | 9 | 28 | – |
| tradeoffs | 24.0% | 18.8% | 21.1% | 32 | 25 | – |
| decisions | 4.8% | 7.7% | 5.9% | 26 | 42 | – |
| todos | 13.0% | 9.4% | 10.9% | 32 | 23 | owner 0.0% |
| open_questions | 7.3% | 33.3% | 12.0% | 9 | 41 | – |

Prose fields (token-set similarity to the reference, informational): title 44.1%, context 17.9%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 9.4% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 18.8% | ❌ |
| schema_valid | ≥ 99.0% | 66.7% | ❌ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 904 | 2.1 | concepts 1/1/4, api_designs 0/0/2, tradeoffs 0/2/2, decisions 0/1/3, todos 0/1/2, open_questions 0/1/4 |
| engineering-002 | ❌ | 904 | 940.7 | api_designs 0/1/0, decisions 0/1/0, todos 0/1/0 |
| engineering-003 | ✅ | 947 | 2.0 | concepts 0/2/0, api_designs 0/0/1, tradeoffs 0/2/2, decisions 1/1/3, todos 1/1/2, open_questions 0/0/1 |
| engineering-004 | ✅ | 872 | 1030.4 | concepts 0/0/3, api_designs 0/0/2, decisions 0/0/3, todos 0/0/2, open_questions 1/1/2 |
| engineering-005 | ✅ | 854 | 2.3 | concepts 1/1/3, tradeoffs 0/0/2, decisions 0/0/3, open_questions 0/0/2 |
| engineering-006 | ❌ | 949 | 254.7 | concepts 0/2/0, tradeoffs 0/2/0, decisions 0/1/0, todos 0/1/0, open_questions 0/1/0 |
| engineering-007 | ✅ | 879 | 4.0 | concepts 0/1/2, api_designs 0/1/2, decisions 0/1/8, todos 1/1/2, open_questions 0/0/3 |
| engineering-008 | ❌ | 862 | 786.6 | todos 0/3/0 |
| engineering-009 | ✅ | 934 | 562.7 | concepts 0/2/0, tradeoffs 0/1/1, decisions 0/1/1, todos 0/1/0, open_questions 0/1/1 |
| engineering-010 | ✅ | 888 | 0.3 | concepts 0/1/0, decisions 0/1/0, todos 0/1/0 |
| engineering-011 | ✅ | 904 | 5.9 | concepts 0/1/0, api_designs 0/1/2, tradeoffs 1/2/1, decisions 0/1/0, todos 0/1/1 |
| engineering-012 | ✅ | 896 | 1019.0 | concepts 1/3/2, api_designs 0/0/5, tradeoffs 0/0/2, decisions 0/0/3, todos 0/0/2, open_questions 1/1/5 |
| engineering-013 | ❌ | 915 | 935.4 | concepts 0/2/0, tradeoffs 0/1/0, decisions 0/1/0, todos 0/1/0 |
| engineering-014 | ✅ | 908 | 2.5 | concepts 0/2/0, api_designs 0/1/2, tradeoffs 0/2/1, decisions 1/1/2, todos 0/1/2, open_questions 0/0/2 |
| engineering-015 | ✅ | 861 | 424.7 | concepts 0/1/1, api_designs 0/0/2, decisions 0/1/0, todos 0/2/1, open_questions 0/1/3 |
| engineering-016 | ❌ | 889 | 15.8 | concepts 0/1/0, tradeoffs 0/2/0, decisions 0/1/0, todos 0/1/0 |
| engineering-017 | ✅ | 1014 | 689.4 | concepts 0/3/0, api_designs 0/1/2, tradeoffs 0/1/0, decisions 0/2/3, todos 0/2/1, open_questions 0/1/3 |
| engineering-018 | ✅ | 890 | 7.1 | concepts 0/1/0, api_designs 0/0/1, tradeoffs 0/0/1, decisions 0/1/2, todos 0/1/0, open_questions 0/0/2 |
| engineering-019 | ✅ | 939 | 908.6 | concepts 0/2/0, tradeoffs 0/2/2, decisions 0/1/3, todos 0/1/2 |
| engineering-020 | ✅ | 901 | 3.9 | concepts 1/1/8, api_designs 0/1/0, tradeoffs 0/0/1, decisions 0/1/2, todos 0/1/2, open_questions 0/0/2 |
| engineering-021 | ✅ | 896 | 252.8 | concepts 1/1/2, api_designs 0/0/1, tradeoffs 0/1/1, decisions 0/1/2, todos 0/1/1, open_questions 0/0/4 |
| engineering-022 | ❌ | 819 | 9.9 | all lists exact |
| engineering-023 | ❌ | 890 | 35.0 | concepts 0/1/0, tradeoffs 0/1/0, decisions 0/1/0, todos 0/1/0 |
| engineering-024 | ✅ | 918 | 4.5 | concepts 1/1/6, api_designs 0/0/2, tradeoffs 1/2/2, decisions 0/1/3, todos 0/2/1, open_questions 0/0/1 |
| engineering-025 | ❌ | 893 | 4.7 | api_designs 0/1/0, tradeoffs 0/2/0, decisions 0/1/0, todos 0/1/0 |
| engineering-026 | ✅ | 875 | 3.7 | concepts 0/2/0, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/4 |
| engineering-027 | ✅ | 920 | 3.5 | concepts 0/2/0, api_designs 0/0/3, tradeoffs 0/1/1, decisions 0/1/0, todos 0/1/0, open_questions 0/1/0 |
| engineering-028 | ✅ | 869 | 4.2 | api_designs 0/0/1, tradeoffs 0/2/0, decisions 0/1/0, todos 0/1/0, open_questions 0/0/1 |
| engineering-029 | ❌ | 905 | 6.3 | concepts 0/1/0, api_designs 0/1/0, tradeoffs 0/1/0, decisions 0/1/0, todos 0/1/0 |
| engineering-030 | ❌ | 901 | 5.9 | concepts 0/1/0, api_designs 0/1/0, decisions 0/1/0, todos 0/1/0 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
