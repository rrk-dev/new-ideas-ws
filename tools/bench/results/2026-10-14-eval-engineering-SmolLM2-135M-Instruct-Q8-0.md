# Extraction eval — `engineering` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: cpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `863fde7` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 89 s incl. model load + Dart compile · peak RSS: 697 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 43.6% |
| Prefill tok/s (median) | 858 |
| Decode tok/s (median) | 151.8 |
| Latency per case (median / max) | 2.6 s / 4.6 s |
| Prompt tokens (median / max) | 1146 / 1262 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 3.4% | 11.1% | 5.2% | 36 | 117 | – |
| api_designs | 6.7% | 22.2% | 10.3% | 9 | 30 | – |
| tradeoffs | 12.1% | 25.0% | 16.3% | 32 | 66 | – |
| decisions | 6.7% | 7.7% | 7.1% | 26 | 30 | – |
| todos | 20.0% | 18.8% | 19.4% | 32 | 30 | owner 16.7% |
| open_questions | 10.0% | 33.3% | 15.4% | 9 | 30 | – |

Prose fields (token-set similarity to the reference, informational): title 59.3%, context 39.4%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 18.8% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 25.0% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 1152 | 3.1 | concepts 1/1/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, open_questions 0/1/1 |
| engineering-002 | ✅ | 1152 | 4.5 | concepts 0/0/20, tradeoffs 0/0/2, decisions 0/1/1, open_questions 0/0/1 |
| engineering-003 | ✅ | 1195 | 3.3 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-004 | ✅ | 1120 | 4.6 | concepts 0/0/2, api_designs 0/0/1, decisions 0/0/1, todos 0/0/1 |
| engineering-005 | ✅ | 1102 | 3.8 | concepts 1/1/20, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-006 | ✅ | 1197 | 3.2 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/1/1 |
| engineering-007 | ✅ | 1127 | 4.1 | concepts 0/1/2, api_designs 0/1/1, decisions 0/1/1, open_questions 0/0/1 |
| engineering-008 | ✅ | 1110 | 2.4 | concepts 0/0/3, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/3/1, open_questions 0/0/1 |
| engineering-009 | ✅ | 1182 | 2.5 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1 |
| engineering-010 | ✅ | 1136 | 2.9 | concepts 0/1/20, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/1/1, open_questions 0/0/1 |
| engineering-011 | ✅ | 1152 | 2.8 | concepts 0/1/2, api_designs 0/1/1, tradeoffs 1/2/2, todos 0/1/1, open_questions 0/0/1 |
| engineering-012 | ✅ | 1144 | 4.2 | concepts 0/3/3, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/0/1, open_questions 0/1/1 |
| engineering-013 | ✅ | 1163 | 3.9 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 1/1/10, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-014 | ✅ | 1156 | 2.4 | concepts 0/2/2, api_designs 0/1/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-015 | ✅ | 1109 | 2.4 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/2/1, open_questions 0/1/1 |
| engineering-016 | ✅ | 1137 | 2.1 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-017 | ✅ | 1262 | 2.4 | concepts 1/3/3, api_designs 0/1/1, tradeoffs 0/1/1, decisions 0/2/1, todos 0/2/1, open_questions 0/1/1 |
| engineering-018 | ✅ | 1138 | 2.6 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-019 | ✅ | 1187 | 2.7 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1 |
| engineering-020 | ✅ | 1149 | 2.4 | concepts 0/1/2, api_designs 0/1/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-021 | ✅ | 1144 | 2.4 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-022 | ✅ | 1067 | 2.1 | concepts 0/0/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/0/1, open_questions 0/0/1 |
| engineering-023 | ✅ | 1138 | 2.2 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-024 | ✅ | 1166 | 2.6 | concepts 0/1/2, api_designs 0/0/1, todos 0/2/1, open_questions 0/0/1 |
| engineering-025 | ✅ | 1141 | 3.1 | concepts 0/0/2, api_designs 0/1/1, tradeoffs 0/2/1, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-026 | ✅ | 1123 | 2.6 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-027 | ✅ | 1168 | 2.5 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/1/1 |
| engineering-028 | ✅ | 1117 | 2.4 | concepts 0/0/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-029 | ✅ | 1153 | 2.5 | concepts 0/1/2, api_designs 0/1/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-030 | ✅ | 1149 | 2.5 | concepts 1/1/2, tradeoffs 0/0/2, decisions 0/1/1, open_questions 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
