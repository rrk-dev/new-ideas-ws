# Extraction eval — `sales_call` × `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6c1a2b4116103267` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 1 · scored: post-processed output
- Cases: 32 (simulated transcripts (no TTS/whisper run), `tools/bench/eval/sales_call/`)
- Wall time: 768 s incl. model load + Dart compile · peak RSS: 2596 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 0.0% |
| Prefill tok/s (median) | 102 |
| Decode tok/s (median) | 21.2 |
| Latency per case (median / max) | 22.9 s / 44.9 s |
| Prompt tokens (median / max) | 1191 / 1454 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| participants | 100.0% | 100.0% | 100.0% | 87 | 87 | – |
| needs | 54.5% | 100.0% | 70.6% | 60 | 110 | – |
| objections | 76.2% | 71.1% | 73.6% | 45 | 42 | – |
| commitments | 48.0% | 46.2% | 47.1% | 52 | 50 | who 95.8% |
| next_steps | 64.4% | 56.9% | 60.4% | 51 | 45 | owner 89.7%, due 89.7% |
| competitors_mentioned | 95.0% | 100.0% | 97.4% | 19 | 20 | – |
| open_questions | 87.5% | 43.8% | 58.3% | 16 | 8 | – |

Prose fields (token-set similarity to the reference, informational): title 73.9%, summary 88.8%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.next_steps.recall | ≥ 60.0% | 56.9% | ❌ |
| lists.next_steps.precision | ≥ 60.0% | 64.4% | ✅ |
| lists.next_steps.owner_accuracy | ≥ 50.0% | 89.7% | ✅ |
| lists.objections.recall | ≥ 50.0% | 71.1% | ✅ |
| lists.commitments.recall | ≥ 50.0% | 46.2% | ❌ |
| lists.needs.recall | ≥ 50.0% | 100.0% | ✅ |
| schema_valid | ≥ 90.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| sales_call-001 | ✅ | 1190 | 26.1 | needs 3/3/6, objections 1/2/1, commitments 0/2/1, next_steps 1/2/1 |
| sales_call-002 | ✅ | 1210 | 26.4 | needs 1/1/2, commitments 1/2/1, next_steps 1/3/1, open_questions 0/1/0 |
| sales_call-003 | ✅ | 1168 | 29.9 | needs 1/1/3, commitments 2/2/3, next_steps 1/3/2 |
| sales_call-004 | ✅ | 1239 | 26.9 | needs 3/3/5, objections 0/2/1, commitments 0/1/1, next_steps 0/2/1 |
| sales_call-005 | ✅ | 1261 | 26.7 | needs 3/3/5, commitments 0/2/1, next_steps 1/3/1, open_questions 0/1/0 |
| sales_call-006 | ✅ | 1205 | 20.0 | needs 2/2/3, commitments 0/1/1, next_steps 1/2/1, open_questions 0/1/0 |
| sales_call-007 | ✅ | 1117 | 15.5 | commitments 1/2/1, next_steps 0/0/1 |
| sales_call-008 | ✅ | 1256 | 23.6 | needs 3/3/6, objections 2/2/3, commitments 0/1/2 |
| sales_call-009 | ✅ | 1194 | 22.8 | needs 2/2/3, objections 0/1/1, commitments 0/1/1, next_steps 0/1/1 |
| sales_call-010 | ✅ | 1454 | 33.3 | needs 2/2/5, objections 1/2/1, commitments 1/2/1, next_steps 1/2/1 |
| sales_call-011 | ✅ | 1183 | 22.5 | needs 2/2/3, objections 0/2/1, open_questions 0/1/0 |
| sales_call-012 | ✅ | 1142 | 27.2 | needs 1/1/2 |
| sales_call-013 | ✅ | 1271 | 44.9 | commitments 2/2/3, next_steps 2/3/2 |
| sales_call-014 | ✅ | 1069 | 21.4 | objections 0/0/1 |
| sales_call-015 | ✅ | 1153 | 22.1 | commitments 1/2/1 |
| sales_call-016 | ✅ | 1155 | 16.4 | needs 2/2/3, commitments 1/2/1, next_steps 0/0/1 |
| sales_call-017 | ✅ | 1400 | 26.1 | needs 1/1/3, objections 2/2/3, commitments 2/2/3 |
| sales_call-018 | ✅ | 1084 | 18.1 | objections 0/1/1, commitments 1/2/2, next_steps 0/1/2 |
| sales_call-019 | ✅ | 1167 | 17.3 | needs 3/3/4, commitments 0/1/1, next_steps 0/1/1 |
| sales_call-020 | ✅ | 1217 | 24.0 | needs 1/1/3, objections 1/2/1, commitments 0/1/1, open_questions 0/1/0 |
| sales_call-021 | ✅ | 1148 | 17.3 | needs 1/1/4, objections 0/0/1, commitments 1/2/1, next_steps 0/2/2 |
| sales_call-022 | ✅ | 1181 | 16.0 | needs 1/1/3, objections 1/2/1, commitments 0/2/1, next_steps 1/2/1 |
| sales_call-023 | ✅ | 1167 | 21.0 | needs 1/1/3, commitments 1/2/3, next_steps 1/2/2 |
| sales_call-024 | ✅ | 1146 | 16.8 | needs 1/1/2, commitments 1/2/1, next_steps 0/0/1, open_questions 0/1/0 |
| sales_call-025 | ✅ | 1403 | 22.6 | needs 1/1/5, commitments 0/1/2, next_steps 1/1/2, competitors_mentioned 0/0/1, open_questions 0/1/1 |
| sales_call-026 | ✅ | 1116 | 20.3 | needs 2/2/3, objections 1/1/2, commitments 1/2/1 |
| sales_call-027 | ✅ | 1199 | 29.0 | needs 2/2/3, objections 0/2/1, commitments 0/1/3, next_steps 2/2/3 |
| sales_call-028 | ✅ | 1192 | 28.5 | needs 3/3/6, commitments 1/2/3, next_steps 1/2/2 |
| sales_call-029 | ✅ | 1230 | 26.6 | needs 2/2/3, commitments 1/2/1 |
| sales_call-030 | ✅ | 1249 | 22.4 | needs 3/3/5, commitments 2/2/4, next_steps 1/2/2, open_questions 0/1/0 |
| sales_call-031 | ✅ | 1242 | 25.9 | needs 3/3/6, objections 1/2/1, commitments 0/1/1, next_steps 1/2/1 |
| sales_call-032 | ✅ | 1155 | 23.1 | needs 1/1/2, commitments 1/2/1, open_questions 0/1/0 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=sales_call MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf`.
