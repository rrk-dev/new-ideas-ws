# LLM default model selection (LLM-08)

Weights: quality 40%, schema_validity 15%, hallucination 10%, speed 15%, ram 10%, license 10%

## Measured candidates

| Model | Quality | Schema-valid | Halluc. | Decode tok/s | Peak RSS MiB | Backend |
|---|---|---|---|---|---|---|
| llama-3.2-1b-instruct-q4_k_m | 64% | 96.7% | 10.8% | 93 | 1203 | gpu |
| smollm2-135m-instruct-q8_0 | 16% | 100.0% | 40.9% | 156 | 677 | cpu |

## Per tier

### free: **llama-3.2-1b-instruct-q4_k_m** (provisional: eligible candidates still unmeasured)
1. llama-3.2-1b-instruct-q4_k_m — 0.687
- needs-eval: gemma-3-1b-it-q4_k_m, qwen2.5-1.5b-instruct-q4_k_m, qwen2.5-0.5b-instruct-q4_k_m
- rejected llama-3.2-3b-instruct-q4_k_m: size 1925 MiB > Free cap 1144; RAM 2406 MiB > budget 1500
- rejected gemma-2-2b-it-q4_k_m: size 1629 MiB > Free cap 1144; RAM 2036 MiB > budget 1500
- rejected gemma-3-4b-it-q4_k_m: size 2375 MiB > Free cap 1144; RAM 2969 MiB > budget 1500
- rejected qwen2.5-3b-instruct-q4_k_m: licence: Qwen Research License; size 1930 MiB > Free cap 1144; RAM 2412 MiB > budget 1500
- rejected qwen3-1.7b-q4_k_m: size 1280 MiB > Free cap 1144; RAM 1600 MiB > budget 1500
- rejected qwen3-4b-q4_k_m: size 2382 MiB > Free cap 1144; RAM 2978 MiB > budget 1500
- rejected phi-4-mini-instruct-q4_k_m: size 2430 MiB > Free cap 1144; RAM 3038 MiB > budget 1500
- rejected smollm2-135m-instruct-q8_0: CI-only model

### low: **llama-3.2-1b-instruct-q4_k_m** (provisional: eligible candidates still unmeasured)
1. llama-3.2-1b-instruct-q4_k_m — 0.687
- needs-eval: gemma-3-1b-it-q4_k_m, qwen2.5-1.5b-instruct-q4_k_m, qwen2.5-0.5b-instruct-q4_k_m
- rejected llama-3.2-3b-instruct-q4_k_m: RAM 2406 MiB > budget 1500
- rejected gemma-2-2b-it-q4_k_m: RAM 2036 MiB > budget 1500
- rejected gemma-3-4b-it-q4_k_m: RAM 2969 MiB > budget 1500
- rejected qwen2.5-3b-instruct-q4_k_m: licence: Qwen Research License; RAM 2412 MiB > budget 1500
- rejected qwen3-1.7b-q4_k_m: RAM 1600 MiB > budget 1500
- rejected qwen3-4b-q4_k_m: RAM 2978 MiB > budget 1500
- rejected phi-4-mini-instruct-q4_k_m: RAM 3038 MiB > budget 1500
- rejected smollm2-135m-instruct-q8_0: CI-only model

### mid: **llama-3.2-1b-instruct-q4_k_m** (provisional: eligible candidates still unmeasured)
1. llama-3.2-1b-instruct-q4_k_m — 0.724
- needs-eval: llama-3.2-3b-instruct-q4_k_m, gemma-2-2b-it-q4_k_m, gemma-3-1b-it-q4_k_m, qwen2.5-1.5b-instruct-q4_k_m, qwen3-1.7b-q4_k_m, qwen2.5-0.5b-instruct-q4_k_m
- rejected gemma-3-4b-it-q4_k_m: RAM 2969 MiB > budget 2800
- rejected qwen2.5-3b-instruct-q4_k_m: licence: Qwen Research License
- rejected qwen3-4b-q4_k_m: RAM 2978 MiB > budget 2800
- rejected phi-4-mini-instruct-q4_k_m: RAM 3038 MiB > budget 2800
- rejected smollm2-135m-instruct-q8_0: CI-only model

### high: **llama-3.2-1b-instruct-q4_k_m** (provisional: eligible candidates still unmeasured)
1. llama-3.2-1b-instruct-q4_k_m — 0.739
- needs-eval: llama-3.2-3b-instruct-q4_k_m, gemma-2-2b-it-q4_k_m, gemma-3-1b-it-q4_k_m, gemma-3-4b-it-q4_k_m, qwen2.5-1.5b-instruct-q4_k_m, qwen3-1.7b-q4_k_m, qwen3-4b-q4_k_m, phi-4-mini-instruct-q4_k_m, qwen2.5-0.5b-instruct-q4_k_m
- rejected qwen2.5-3b-instruct-q4_k_m: licence: Qwen Research License
- rejected smollm2-135m-instruct-q8_0: CI-only model

