# Device verification — LLM-05 Structured output via constrained decoding

Host results: `tools/bench/results/2026-10-13-llm05-grammar.md` (lazy grammar ≈ 0% overhead on
Llama-3.2-1B Metal and CPU; full mask −54% / −24%) and `[LLM-05/AC1]` host test (SmolLM2, 25/25
schema-valid on synthetic transcripts). The PRF-09 eval set (real Whisper output, ≥ 30 cases per
built-in profile) does not exist yet — AC1's ≥ 99% must be re-run on it when PRF-09 lands
(`tools/bench/eval/run.py`, not part of this task).

Models: see LLM-02 / LLM-03 device docs. Commands from `app/`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-05/AC2] | `fvm flutter test integration_test/llm_grammar_test.dart --flavor dev -d <id> --dart-define=VV_LLM_BENCH_MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf` | Passes; `VV_LLM_GRAMMAR {…}` shows `lazy_overhead` < 0.20; paste the line below | iPhone 15 Pro / 16 (VV-IOS-16), Metal | iOS 18+ | | | |
| [LLM-05/AC2] | Same with `Llama-3.2-1B-Instruct-Q4_K_M.gguf` | Same | iPhone 11 (VV-IOS-11) | iOS 16+ | | | |
| [LLM-05/AC2] | Same with `Llama-3.2-3B-Instruct-Q4_0.gguf --dart-define=VV_LLM_BENCH_GPU=0` (CPU) | Same | Snapdragon 8 Gen 3 (VV-AND-FLG) + VV-AND-7 | Android 14+ / 13+ | | | |
| [LLM-05/AC1] | When PRF-09 exists: run the eval harness for every built-in profile with the tier default model on the device runner | `schema_valid` ≥ 99% per profile (after one repair; summary-only fallbacks count as invalid) | VV-IOS-16 + VV-AND-FLG | — | | | |
