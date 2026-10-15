# STT-07 — STT Model Variants & Language Support

**Workstream:** STT | **Phase:** 2 | **Size:** S | **Depends on:** STT-03, MDL-01 | **Source:** §4.2, §7 (tiny/small for Free, high-accuracy for Pro)
**Status:** review
**Skills:** vv-task-workflow, vv-whisper-stt, vv-benchmark-eval, vv-model-delivery, vv-licensing-iap

## Goal
Define the set of Whisper models offered, their tiers, and language handling.

## Scope
- [x] Benchmark tiny.en, base.en, small.en, large-v3-turbo (quantized Q5/Q8) for WER, speed, RAM, size.
- [x] Map to tiers: Free = tiny/base; Pro = small / large-v3-turbo (where device RAM allows — LLM-07).
- [x] Multilingual variants for non-English users (language auto-detect or user-selected): Free `ggml-base-q5_1`, Pro `ggml-small-q5_1` / large-v3-turbo (see `vv-whisper-stt` tier table).
- [x] Per-device recommended default.

## Acceptance Criteria
- Model matrix (WER/RTF/RAM/size per device class) published in `docs/models.md`.
- Free vs Pro STT models enforced through LIC-01 entitlements.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-07-stt-model-variants (base origin/main; not stacked) · **Date:** 2026-10-14
- **Summary:**
  - Benchmark harness `tools/bench/stt_variants/` (`passages.jsonl` scripted texts,
    `make_corpus.sh` macOS TTS → 16 kHz WAV in `~/.cache/vaultvoice/bench/corpus`, `run.py` WER +
    RTF Metal/CPU + load + peak RSS per model); `native/tests/stt_backends.cpp bench` gained
    `--lang`, `--hyp-out`, `--seconds 0` and `peak_rss_mb`. Results
    `tools/bench/results/2026-10-14-stt07-variants{,-run1}.{md,json}`; matrix, findings, tier ×
    plan defaults, enforcement and language handling in `docs/models.md`.
  - Catalog: 8 new STT entries (tiny.en-q5_1, base.en-q5_1, base.en, small.en-q5_1, small.en-q8_0,
    base-q5_1, small-q5_1, large-v3-turbo-q5_0) in `tools/model-catalog/models.json` with sizes +
    SHA-256 computed from the downloaded files (equal to the HF LFS etag), rebuilt + re-signed
    `app/assets/catalog/catalog.json(.sig)`. The 2026a dev key's private half was not available, so
    a second **development** key `vv-catalog-dev-2026b` (key_id `8d4a64af2e67eeaf`, private half
    outside the repo at `~/.config/vaultvoice-dev-keys/`) is pinned next to 2026a in
    `catalog_keys.dart` (max two keys; production key = MDL-05). `test_catalog.py` model count is
    now derived from `models.json`.
  - Policy `app/lib/features/transcription/domain/stt_model_policy.dart`: `SttVariant` (size,
    `.en`, quant from the ggml file name), `sttFeatureFor` (small → `Feature.smallStt`,
    medium/large → `Feature.highAccuracyStt`), `SttPlanGate` (backed by LIC-01
    `EntitlementService`; `sttPlanGateProvider` in `data/stt_model_providers.dart`),
    `sttModelEntitled`/`sttModelAccess` (feature **and** catalog tier), bench-driven
    `kSttPreference` + `recommendedSttModel` (per device tier × plan × language family, filtered by
    `min_ram_mb`), `resolveSttModel` (selection → fallback; downgrade-safe), language helpers.
- **Host numbers (Apple M3 Pro, whisper.cpp v1.9.5, Metal, greedy; machine shared by 8 agents,
  load 50–400 → RTF noisy, WER deterministic):** WER en tiny.en 4.0 %, tiny.en-q5_1 4.2 %, base.en
  3.6 %, base.en-q5_1 3.6 %, small.en-q5_1 2.6 %, small.en-q8_0 3.0 %, base-q5_1 3.6 % (de/fr/es
  2.7 %), small-q5_1 2.4 % (2.7 %), large-v3-turbo-q5_0 2.0 % (0.0 %), large-v3-turbo-q8_0 2.8 %
  (0.0 %); RTF Metal 0.010–0.093; peak RSS (CPU) 324 MB (tiny) … 1079 MB (turbo q5_0). Full
  table: `docs/models.md`.
- **Gates (2026-10-14, macOS host):** `native/build.sh host` 23/23 ctest; `dart format` clean,
  `flutter analyze` 0, `dart analyze --fatal-infos` 0, `flutter test` all passed,
  `pytest tools/ci/tests` + `tools/model-catalog/tests` passed, `check_recording_policy`,
  `check_egress`, `check_codegen` OK.
- **Acceptance evidence:**
  - AC1: ⏳ artifact: docs/models.md; artifact: tools/bench/results/2026-10-14-stt07-variants.md; device: docs/test-plans/device/STT-07.md
  - AC2: ✅ test: [STT-07/AC2]
- **Decisions:** data-driven defaults recorded in `docs/models.md` (q5_1 everywhere; small.en-q5_1
  for Pro Low/Mid; large-v3-turbo-q5_0 for Pro High). PRODUCT-DECISIONs: `small` is Pro
  (LIC-01 cell); turbo is the Pro High default for English too; default language follows the
  device locale.
- **Follow-ups:** STT-09; MDL-03 / FND-11 wiring (see below).

## Follow-ups
- Codex review 2026-10-15 (open): Production selection bypasses STT size-class entitlements for sideloaded/unknown models (active_models.dart:125); needs a licensing decision (language filtering of candidates is fixed).
- STT-09 (proposed): on-device CPU-only RTF of large-v3-turbo-q5_0 (iOS background has no
  Metal) — if it misses the budget, resolve to small.en/small for background jobs.
- MDL-03 (model management UI) and FND-11 (engine wiring) should pick/load the STT model through
  `resolveSttModel` + `sttPlanGateProvider` and pass `sttLanguageFor(...)` as the decode language;
  `defaultsFor` in `features/extraction/domain/device_tiering.dart` still picks the STT model with
  the LLM plan gate — switch it to `recommendedSttModel` (LLM group's file, not changed here).
- Integration: the catalog is now signed with dev key 2026b; any other branch that re-signs the
  catalog must rebuild from the merged `models.json` with one key (MDL-05 production key).

