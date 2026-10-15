# Device verification — LLM-08 Default LLM model evaluation

Host numbers (Llama-3.2-1B Q4_K_M, SmolLM2 CI model): `tools/bench/results/2026-10-15-llm08-selection.md`.
The ADR stays **Proposed** until the rows below are filled (device tok/s, RAM) and the unmeasured
candidates are run through `make eval-all`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-08/AC1] ⏳ | Run the PRF-09 cases with each shortlisted model (1B, 3B, Gemma-3-1B/4B, Qwen2.5-1.5B, Qwen3-1.7B/4B) via the on-device runner; record decode tok/s, peak footprint, thermal state | Numbers feed `tools/bench/results/*eval*.json` → `make llm-select`; ADR-LLM-08 moves to Accepted | iPhone 11 (VV-IOS-11) low tier | iOS 16+ | | | |
| [LLM-08/AC1] ⏳ | Same, 3B and 4B-class models only | Mid/High default confirmed or replaced | iPhone 14/15 Pro (VV-IOS-16) | iOS 17+ | | | |
| [LLM-08/AC1] ⏳ | Same on Android flagship + budget | Low/Mid defaults confirmed | VV-AND-FLG, VV-AND-LOW | Android 14+ | | | |
