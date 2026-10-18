# Mind-map eval — `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu · commit: `ee846aa` + uncommitted changes
- Cases: 36 (simulated transcripts, `tools/bench/eval/mindmap/`); wall time 1387 s incl. model load
- Extraction (shared by A and C): valid 100.0%, median 23.5 s per case
- Limits: depth ≤ 3, nodes ≤ 40, label ≤ 60

## Options

| Option | schema_valid | label_grounding | concept_recall | limits_compliance | rejected | avg nodes | latency median / max |
|---|---|---|---|---|---|---|---|
| projection | 100.0% | 69.8% | 76.6% | 100.0% | 0.0% | 18.9 | 0.00 s / 0.01 s |
| llm | 100.0% | 99.7% | 45.2% | 100.0% | 0.0% | 8.5 | 10.18 s / 56.62 s |
| hybrid | 100.0% | 99.7% | 82.7% | 100.0% | 0.0% | 27.1 | 0.01 s / 0.02 s |

Latency is the generation step only (the extraction it reuses is reported above); `llm` and `hybrid` share one LLM call, whose wall time is 10.2 s median.

## Chosen option: `hybrid`

## Targets (chosen option)

| Target | Required | Actual | |
|---|---|---|---|
| schema_valid | ≥ 90.0% | 100.0% | ✅ |
| label_grounding | ≥ 85.0% | 99.7% | ✅ |
| concept_recall | ≥ 50.0% | 82.7% | ✅ |
| limits_compliance | ≥ 100.0% | 100.0% | ✅ |
