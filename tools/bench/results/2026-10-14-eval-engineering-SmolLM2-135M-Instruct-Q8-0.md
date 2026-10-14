# Extraction eval — `engineering` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: cpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `279469c` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 92 s incl. model load + Dart compile · peak RSS: 656 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 49.8% |
| Prefill tok/s (median) | 919 |
| Decode tok/s (median) | 175.9 |
| Latency per case (median / max) | 2.6 s / 6.3 s |
| Prompt tokens (median / max) | 1177 / 1293 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 2.9% | 8.3% | 4.3% | 36 | 104 | – |
| api_designs | 3.3% | 11.1% | 5.1% | 9 | 30 | – |
| tradeoffs | 10.4% | 21.9% | 14.1% | 32 | 67 | – |
| decisions | 3.2% | 3.8% | 3.5% | 26 | 31 | – |
| todos | 10.0% | 9.4% | 9.7% | 32 | 30 | owner 66.7% |
| open_questions | 12.9% | 44.4% | 20.0% | 9 | 31 | – |

Prose fields (token-set similarity to the reference, informational): title 52.6%, context 36.7%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 9.4% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 21.9% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 1183 | 6.3 | concepts 1/1/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, open_questions 0/1/1 |
| engineering-002 | ✅ | 1183 | 4.0 | concepts 0/0/20, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-003 | ✅ | 1226 | 2.6 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-004 | ✅ | 1151 | 2.5 | concepts 0/0/2, api_designs 0/0/1, decisions 0/0/1, todos 0/0/1 |
| engineering-005 | ✅ | 1133 | 2.7 | concepts 1/1/5, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, open_questions 0/0/1 |
| engineering-006 | ✅ | 1228 | 2.8 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 1/2/2, decisions 0/1/2, todos 0/1/1, open_questions 0/1/2 |
| engineering-007 | ✅ | 1158 | 2.1 | concepts 1/1/6, api_designs 0/1/1, tradeoffs 1/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-008 | ✅ | 1141 | 1.8 | concepts 0/0/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/3/1, open_questions 0/0/1 |
| engineering-009 | ✅ | 1213 | 2.4 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1 |
| engineering-010 | ✅ | 1167 | 2.1 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-011 | ✅ | 1183 | 2.0 | concepts 0/1/2, api_designs 0/1/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-012 | ✅ | 1175 | 2.1 | concepts 0/3/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/0/1 |
| engineering-013 | ✅ | 1194 | 3.1 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 1/1/10, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-014 | ✅ | 1187 | 2.2 | concepts 0/2/2, api_designs 0/1/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-015 | ✅ | 1140 | 2.0 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/2/1, open_questions 0/1/1 |
| engineering-016 | ✅ | 1168 | 2.1 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-017 | ✅ | 1293 | 2.9 | concepts 0/3/20, api_designs 0/1/1, tradeoffs 0/1/1, decisions 0/2/1, todos 0/2/1, open_questions 0/1/1 |
| engineering-018 | ✅ | 1169 | 2.3 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-019 | ✅ | 1218 | 2.4 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1 |
| engineering-020 | ✅ | 1180 | 2.1 | concepts 0/1/2, api_designs 0/1/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-021 | ✅ | 1175 | 2.0 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-022 | ✅ | 1098 | 1.9 | concepts 0/0/2, api_designs 0/0/1, tradeoffs 0/0/2, decisions 0/0/1, todos 0/0/1, open_questions 0/0/1 |
| engineering-023 | ✅ | 1169 | 2.6 | concepts 0/1/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-024 | ✅ | 1197 | 4.5 | concepts 0/1/2, api_designs 0/0/1, todos 0/2/1, open_questions 0/0/1 |
| engineering-025 | ✅ | 1172 | 4.1 | concepts 0/0/2, api_designs 0/1/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-026 | ✅ | 1154 | 3.0 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-027 | ✅ | 1199 | 3.2 | concepts 0/2/2, api_designs 0/0/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/1/1 |
| engineering-028 | ✅ | 1148 | 3.8 | concepts 0/0/2, api_designs 0/0/1, tradeoffs 0/2/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-029 | ✅ | 1184 | 6.2 | concepts 0/1/3, api_designs 0/1/1, tradeoffs 0/1/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |
| engineering-030 | ✅ | 1180 | 5.6 | concepts 0/1/2, api_designs 0/1/1, tradeoffs 0/0/2, decisions 0/1/1, todos 0/1/1, open_questions 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
