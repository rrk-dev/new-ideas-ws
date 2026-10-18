# Auto-classification eval — `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu · stage: keywords + LLM
- Commit: `fbfc25e` + uncommitted changes · cases: 144 (simulated transcripts, `tools/bench/eval/classify/`)
- Wall time: 25 s incl. model load + Dart compile · peak RSS: 1818 MiB

## Summary

| Metric | Value |
|---|---|
| Accuracy (all) | 93.8% |
| Accuracy dev / holdout | 94.4% / 93.1% |
| Accuracy clear / ambiguous / injection | 99.0% / 83.3% / 83.3% |
| Keyword stage decided / precision | 130 / 99.2% |
| LLM stage decided / accuracy | 14 / 42.9% |
| Not decided (keyword-only run) | 0 |
| User asked (low confidence) | 9.0% |
| Wrong and not asked | 0.7% |
| LLM-stage latency median / max (host CPU) | 1.6 s / 1.7 s |

## Confusion matrix (rows = label, columns = picked)

| label \ picked | meeting | warranty | engineering | lecture | sales_call | interview | none | recall |
|---|---|---|---|---|---|---|---|---|
| **meeting** | 24 | 0 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| **warranty** | 4 | 20 | 0 | 0 | 0 | 0 | 0 | 83.3% |
| **engineering** | 0 | 0 | 24 | 0 | 0 | 0 | 0 | 100.0% |
| **lecture** | 0 | 0 | 0 | 23 | 0 | 1 | 0 | 95.8% |
| **sales_call** | 1 | 0 | 0 | 0 | 22 | 1 | 0 | 91.7% |
| **interview** | 0 | 0 | 0 | 1 | 1 | 22 | 0 | 91.7% |
| precision | 82.8% | 100.0% | 100.0% | 95.8% | 95.7% | 91.7% | | |

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| accuracy | ≥ 90.0% | 93.8% | ✅ |
| accuracy_holdout | ≥ 90.0% | 93.1% | ✅ |
| accuracy_ambiguous | ≥ 75.0% | 83.3% | ✅ |
| recall_per_profile | ≥ 80.0% (min over profiles) | 83.3% | ✅ |
| confident_wrong_rate_max | ≤ 5.0% | 0.7% | ✅ |
| keyword_precision | ≥ 95.0% | 99.2% | ✅ |

## Misclassified cases (9)

| Case | Label | Picked | Method | Confidence | Tags |
|---|---|---|---|---|---|
| classify-011 | warranty | meeting | llm | 0.00 | ambiguous / dev |
| classify-017 | sales_call | meeting | llm | 0.00 | ambiguous / dev |
| classify-020 | warranty | meeting | llm | 0.00 | ambiguous / holdout |
| classify-043 | interview | lecture | llm | 0.00 | ambiguous / dev |
| classify-066 | warranty | meeting | llm | 0.00 | ambiguous / holdout |
| classify-083 | warranty | meeting | llm | 0.00 | ambiguous / dev |
| classify-090 | sales_call | interview | llm | 0.00 | clear, injection / holdout |
| classify-100 | interview | sales_call | keyword | 0.95 | ambiguous / holdout |
| classify-124 | lecture | interview | llm | 0.00 | ambiguous / holdout |
