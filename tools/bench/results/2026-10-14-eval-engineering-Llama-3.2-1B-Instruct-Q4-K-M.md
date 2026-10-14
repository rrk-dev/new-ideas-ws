# Extraction eval — `engineering` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `863fde7` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 176 s incl. model load + Dart compile · peak RSS: 1224 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 96.7% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 14.5% |
| Prefill tok/s (median) | 4256 |
| Decode tok/s (median) | 86.5 |
| Latency per case (median / max) | 4.4 s / 11.8 s |
| Prompt tokens (median / max) | 993 / 1087 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 23.8% | 83.3% | 37.0% | 36 | 126 | – |
| api_designs | 2.4% | 33.3% | 4.5% | 9 | 124 | – |
| tradeoffs | 13.5% | 65.6% | 22.3% | 32 | 156 | – |
| decisions | 9.2% | 42.3% | 15.1% | 26 | 120 | – |
| todos | 55.2% | 50.0% | 52.5% | 32 | 29 | owner 75.0% |
| open_questions | 3.0% | 55.6% | 5.8% | 9 | 164 | – |

Prose fields (token-set similarity to the reference, informational): title 74.5%, context 56.0%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 50.0% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 65.6% | ❌ |
| schema_valid | ≥ 99.0% | 96.7% | ❌ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 997 | 3.9 | concepts 1/1/6, api_designs 0/0/3, tradeoffs 0/2/3, decisions 1/1/2, open_questions 0/1/2 |
| engineering-002 | ✅ | 997 | 6.6 | concepts 0/0/4, api_designs 1/1/4, tradeoffs 0/0/10, decisions 0/1/4, todos 0/1/1, open_questions 0/0/2 |
| engineering-003 | ✅ | 1036 | 7.4 | concepts 2/2/8, api_designs 0/0/4, tradeoffs 2/2/10, decisions 1/1/3, open_questions 0/0/4 |
| engineering-004 | ✅ | 970 | 8.7 | concepts 0/0/7, api_designs 0/0/4, tradeoffs 2/2/4, decisions 0/0/8, todos 0/0/1, open_questions 0/1/20 |
| engineering-005 | ✅ | 958 | 4.7 | concepts 1/1/4, api_designs 0/0/2, tradeoffs 0/0/10, decisions 0/0/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-006 | ✅ | 1035 | 3.0 | concepts 2/2/4, api_designs 0/0/1, tradeoffs 2/2/4, decisions 0/1/1, open_questions 1/1/2 |
| engineering-007 | ❌ | 978 | 11.8 | concepts 0/1/0, api_designs 0/1/0, tradeoffs 0/2/0, decisions 0/1/0, todos 0/1/0 |
| engineering-008 | ✅ | 963 | 3.0 | concepts 0/0/4, api_designs 0/0/3, tradeoffs 0/0/3, decisions 0/0/1, todos 1/3/1, open_questions 0/0/1 |
| engineering-009 | ✅ | 1022 | 10.0 | concepts 2/2/5, api_designs 0/0/4, tradeoffs 1/1/8, decisions 0/1/4, todos 0/1/1, open_questions 1/1/20 |
| engineering-010 | ✅ | 981 | 2.8 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 0/0/4, decisions 0/1/1, open_questions 0/0/1 |
| engineering-011 | ✅ | 995 | 5.6 | concepts 1/1/5, api_designs 0/1/1, tradeoffs 2/2/10, decisions 1/1/3, open_questions 0/0/2 |
| engineering-012 | ✅ | 993 | 11.0 | concepts 3/3/8, api_designs 0/0/10, tradeoffs 0/0/10, decisions 0/0/9, todos 0/0/1, open_questions 0/1/20 |
| engineering-013 | ✅ | 1009 | 3.4 | concepts 2/2/4, api_designs 0/0/3, tradeoffs 1/1/3, decisions 0/1/1, open_questions 0/0/1 |
| engineering-014 | ✅ | 1002 | 3.9 | concepts 2/2/4, api_designs 1/1/4, tradeoffs 1/2/4, decisions 0/1/1, open_questions 0/0/2 |
| engineering-015 | ✅ | 965 | 3.6 | concepts 1/1/4, api_designs 0/0/3, tradeoffs 0/0/3, decisions 0/1/1, todos 0/2/1, open_questions 0/1/3 |
| engineering-016 | ✅ | 986 | 9.6 | concepts 1/1/4, api_designs 0/0/10, tradeoffs 2/2/4, decisions 1/1/8, open_questions 0/0/20 |
| engineering-017 | ✅ | 1087 | 8.5 | concepts 1/3/5, api_designs 0/1/5, tradeoffs 0/1/10, decisions 0/2/20, todos 0/2/1, open_questions 1/1/20 |
| engineering-018 | ✅ | 979 | 3.4 | concepts 0/1/3, api_designs 0/0/3, tradeoffs 0/0/3, decisions 1/1/2, todos 0/1/1, open_questions 0/0/1 |
| engineering-019 | ✅ | 1027 | 4.4 | concepts 2/2/5, api_designs 0/0/1, tradeoffs 2/2/10, decisions 0/1/1, open_questions 1/1/3 |
| engineering-020 | ✅ | 993 | 10.1 | concepts 0/1/4, api_designs 1/1/10, tradeoffs 0/0/1, decisions 0/1/20, todos 0/1/1, open_questions 0/0/1 |
| engineering-021 | ✅ | 988 | 2.6 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 1/1/4, decisions 0/1/1, open_questions 0/0/2 |
| engineering-022 | ✅ | 928 | 8.3 | concepts 0/0/2, api_designs 0/0/10, tradeoffs 0/0/10, decisions 0/0/10, todos 0/0/1, open_questions 0/0/1 |
| engineering-023 | ✅ | 984 | 3.7 | concepts 1/1/5, api_designs 0/0/4, tradeoffs 1/1/4, open_questions 0/0/2 |
| engineering-024 | ✅ | 1010 | 2.1 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 1/2/1, decisions 1/1/2, todos 1/2/1, open_questions 0/0/2 |
| engineering-025 | ✅ | 989 | 2.5 | concepts 0/0/3, api_designs 0/1/1, tradeoffs 0/2/3, decisions 1/1/3, open_questions 0/0/2 |
| engineering-026 | ✅ | 977 | 4.5 | concepts 2/2/5, api_designs 0/0/10, tradeoffs 0/1/1, decisions 0/1/1, open_questions 0/0/1 |
| engineering-027 | ✅ | 1009 | 7.7 | concepts 2/2/4, api_designs 0/0/6, tradeoffs 1/1/3, decisions 1/1/4, todos 0/1/1, open_questions 1/1/20 |
| engineering-028 | ✅ | 967 | 9.4 | concepts 0/0/4, api_designs 0/0/10, tradeoffs 1/2/10, decisions 0/1/3, todos 0/1/1, open_questions 0/0/3 |
| engineering-029 | ✅ | 996 | 3.3 | concepts 0/1/4, api_designs 0/1/3, tradeoffs 1/1/3, decisions 1/1/2, open_questions 0/0/2 |
| engineering-030 | ✅ | 1000 | 3.8 | concepts 1/1/2, api_designs 0/1/2, tradeoffs 0/0/3, decisions 1/1/2, todos 0/1/1, open_questions 0/0/3 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
