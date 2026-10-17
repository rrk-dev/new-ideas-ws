# Extraction eval — `sales_call` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `8ddb8c0` · llama.cpp `d812350` · profile version 1 · scored: post-processed output
- Cases: 32 (simulated transcripts (no TTS/whisper run), `tools/bench/eval/sales_call/`)
- Wall time: 408 s incl. model load + Dart compile · peak RSS: 1809 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 1.7% |
| Prefill tok/s (median) | 235 |
| Decode tok/s (median) | 46.3 |
| Latency per case (median / max) | 11.7 s / 25.7 s |
| Prompt tokens (median / max) | 1191 / 1454 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| participants | 100.0% | 100.0% | 100.0% | 87 | 87 | – |
| needs | 44.6% | 83.3% | 58.1% | 60 | 112 | – |
| objections | 30.8% | 73.3% | 43.4% | 45 | 107 | – |
| commitments | 39.0% | 44.2% | 41.4% | 52 | 59 | who 95.7% |
| next_steps | 56.4% | 60.8% | 58.5% | 51 | 55 | owner 80.6%, due 6.5% |
| competitors_mentioned | 59.4% | 100.0% | 74.5% | 19 | 32 | – |
| open_questions | 11.6% | 62.5% | 19.6% | 16 | 86 | – |

Prose fields (token-set similarity to the reference, informational): title 82.0%, summary 64.5%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.next_steps.recall | ≥ 60.0% | 60.8% | ✅ |
| lists.next_steps.precision | ≥ 60.0% | 56.4% | ❌ |
| lists.next_steps.owner_accuracy | ≥ 50.0% | 80.6% | ✅ |
| lists.objections.recall | ≥ 50.0% | 73.3% | ✅ |
| lists.commitments.recall | ≥ 50.0% | 44.2% | ❌ |
| lists.needs.recall | ≥ 50.0% | 83.3% | ✅ |
| schema_valid | ≥ 90.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| sales_call-001 | ✅ | 1190 | 17.6 | needs 3/3/6, objections 2/2/9, commitments 0/2/2, competitors_mentioned 0/0/1, open_questions 0/0/8 |
| sales_call-002 | ✅ | 1210 | 8.6 | needs 1/1/3, objections 1/1/2, commitments 1/2/2, next_steps 1/3/2, open_questions 0/1/3 |
| sales_call-003 | ✅ | 1168 | 7.2 | needs 1/1/2, objections 1/1/2, commitments 1/2/2, next_steps 0/3/1, competitors_mentioned 0/0/1, open_questions 0/0/2 |
| sales_call-004 | ✅ | 1239 | 8.5 | objections 1/2/2, commitments 1/1/2, next_steps 1/2/2, competitors_mentioned 0/0/1, open_questions 0/0/2 |
| sales_call-005 | ✅ | 1261 | 12.3 | needs 3/3/7, objections 1/1/2, commitments 0/2/1, next_steps 1/3/1, open_questions 1/1/2 |
| sales_call-006 | ✅ | 1205 | 12.1 | needs 2/2/3, objections 1/1/2, commitments 1/1/2, next_steps 1/2/1, open_questions 0/1/2 |
| sales_call-007 | ✅ | 1117 | 15.6 | needs 3/3/4, objections 1/1/3, commitments 1/2/2, next_steps 0/0/2, open_questions 0/0/3 |
| sales_call-008 | ✅ | 1256 | 11.7 | needs 2/3/3, commitments 0/1/2, next_steps 1/2/1, competitors_mentioned 0/0/1, open_questions 1/1/2 |
| sales_call-009 | ✅ | 1194 | 10.9 | needs 2/2/4, objections 0/1/2, commitments 0/1/2, open_questions 1/1/2 |
| sales_call-010 | ✅ | 1454 | 14.1 | needs 2/2/4, objections 1/2/2, commitments 1/2/2, next_steps 1/2/2, open_questions 0/0/2 |
| sales_call-011 | ✅ | 1183 | 12.6 | needs 1/2/4, objections 0/2/2, commitments 1/1/2, next_steps 1/1/2, open_questions 1/1/4 |
| sales_call-012 | ✅ | 1142 | 10.1 | needs 0/1/3, objections 1/1/2, commitments 1/1/2, next_steps 1/2/1, open_questions 0/0/2 |
| sales_call-013 | ✅ | 1271 | 12.1 | needs 3/3/4, objections 0/2/2, next_steps 2/3/2, competitors_mentioned 0/0/1 |
| sales_call-014 | ✅ | 1069 | 11.7 | needs 1/1/2, objections 0/0/7, next_steps 0/1/1, open_questions 0/0/4 |
| sales_call-015 | ✅ | 1153 | 8.9 | needs 1/1/2, objections 1/1/2, commitments 0/2/1, open_questions 0/0/3 |
| sales_call-016 | ✅ | 1155 | 10.0 | needs 2/2/4, objections 1/1/2, commitments 1/2/1, next_steps 0/0/1, open_questions 0/1/1 |
| sales_call-017 | ✅ | 1400 | 14.1 | needs 0/1/3, objections 0/2/2, commitments 1/2/3, next_steps 1/2/2, open_questions 0/0/1 |
| sales_call-018 | ✅ | 1084 | 11.6 | needs 1/1/2, objections 1/1/2, commitments 0/2/2, next_steps 1/1/2, competitors_mentioned 0/0/1, open_questions 0/0/4 |
| sales_call-019 | ✅ | 1167 | 12.0 | needs 2/3/3, objections 1/1/2, commitments 0/1/1, next_steps 1/1/2, competitors_mentioned 0/0/1, open_questions 0/0/2 |
| sales_call-020 | ✅ | 1217 | 11.5 | needs 1/1/2, objections 2/2/3, commitments 0/1/1, next_steps 1/1/2 |
| sales_call-021 | ✅ | 1148 | 17.0 | needs 1/1/2, objections 0/0/7, open_questions 1/1/7 |
| sales_call-022 | ✅ | 1181 | 16.4 | needs 1/1/2, objections 2/2/3, commitments 0/2/2, competitors_mentioned 0/0/1, open_questions 0/0/1 |
| sales_call-023 | ✅ | 1167 | 10.8 | needs 0/1/2, commitments 0/2/1, next_steps 1/2/1, competitors_mentioned 0/0/1, open_questions 0/0/2 |
| sales_call-024 | ✅ | 1146 | 16.7 | needs 1/1/3, objections 1/1/4, next_steps 0/0/2, open_questions 0/1/0 |
| sales_call-025 | ✅ | 1403 | 25.7 | needs 1/1/8, objections 1/2/5, commitments 0/1/4, next_steps 1/1/4, competitors_mentioned 0/0/1, open_questions 0/1/5 |
| sales_call-026 | ✅ | 1116 | 10.9 | needs 1/2/3, objections 1/1/2, next_steps 1/1/2, open_questions 0/0/1 |
| sales_call-027 | ✅ | 1199 | 13.6 | needs 2/2/3, objections 2/2/5, next_steps 1/2/1, open_questions 0/0/2 |
| sales_call-028 | ✅ | 1192 | 10.8 | needs 2/3/4, commitments 0/2/2, next_steps 1/2/1, competitors_mentioned 0/0/1, open_questions 0/0/3 |
| sales_call-029 | ✅ | 1230 | 21.1 | needs 2/2/9, objections 2/2/10, commitments 1/2/4, next_steps 1/1/4, competitors_mentioned 0/0/1, open_questions 1/1/8 |
| sales_call-030 | ✅ | 1249 | 10.1 | needs 2/3/3, objections 1/1/5, commitments 1/2/1, next_steps 0/2/1, open_questions 0/1/2 |
| sales_call-031 | ✅ | 1242 | 7.5 | needs 2/3/2, objections 1/2/2, commitments 0/1/1, competitors_mentioned 0/0/1 |
| sales_call-032 | ✅ | 1155 | 10.1 | needs 1/1/3, objections 0/1/6, commitments 1/2/2, next_steps 1/1/2, open_questions 1/1/3 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=sales_call MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
