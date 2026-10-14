# STT-07 — STT Model Variants & Language Support

**Workstream:** STT | **Phase:** 2 | **Size:** S | **Depends on:** STT-03, MDL-01 | **Source:** §4.2, §7 (tiny/small for Free, high-accuracy for Pro)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-whisper-stt, vv-benchmark-eval, vv-model-delivery, vv-licensing-iap

## Goal
Define the set of Whisper models offered, their tiers, and language handling.

## Scope
- [ ] Benchmark tiny.en, base.en, small.en, large-v3-turbo (quantized Q5/Q8) for WER, speed, RAM, size.
- [ ] Map to tiers: Free = tiny/base; Pro = small / large-v3-turbo (where device RAM allows — LLM-07).
- [ ] Multilingual variants for non-English users (language auto-detect or user-selected): Free `ggml-base-q5_1`, Pro `ggml-small-q5_1` / large-v3-turbo (see `vv-whisper-stt` tier table).
- [ ] Per-device recommended default.

## Acceptance Criteria
- Model matrix (WER/RTF/RAM/size per device class) published in `docs/models.md`.
- Free vs Pro STT models enforced through LIC-01 entitlements.
