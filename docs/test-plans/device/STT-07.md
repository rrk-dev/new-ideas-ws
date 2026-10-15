# Device verification — STT-07 STT Model Variants & Language Support

The host matrix (`docs/models.md`, raw data `tools/bench/results/2026-10-14-stt07-variants.*`)
ranks the variants; these rows fill the per-device-class columns. Use the same corpus
(`tools/bench/stt_variants/make_corpus.sh`) and the on-device bench runner (STT-03 integration
test / QA-02 harness): 3+ runs, report median and min–max, start at nominal thermal state,
airplane mode, plugged in. Record RTF with GPU (Metal / Vulkan / OpenCL per backend policy) and
CPU-only, and peak RSS (`vv_proc_memory` → `phys_footprint` / `VmHWM`).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-07/AC1] | Low tier: run tiny.en-q5_1, base.en-q5_1, small.en-q5_1, base-q5_1, small-q5_1 on the corpus (CPU + GPU); fill the Low columns of the `docs/models.md` device matrix. | Recommended Low models (base.en-q5_1 Free, small.en-q5_1 Pro) run with RTF ≤ 0.5 (CPU) and peak RSS below the catalog `min_ram_mb`; WER within 1 pt of the host value. | iPhone 11 (4 GB) | iOS 18.x | ⏳ | | |
| [STT-07/AC1] | Same models as Low. | Same as Low. | Android 4 GB (Pixel 4a / Galaxy A-series) | Android 14+ | ⏳ | | |
| [STT-07/AC1] | Mid tier: add small.en-q8_0. | small.en-q5_1 (Pro default) RTF ≤ 0.3 GPU; RSS < 1 GB. | iPhone 13 / 6 GB Android | iOS 18.x / Android 15 | ⏳ | | |
| [STT-07/AC1] | High tier: add large-v3-turbo-q5_0 (GPU and CPU-only — CPU is what iOS background uses). | large-v3-turbo-q5_0 RTF ≤ 0.25 GPU; CPU-only RTF recorded (decides whether background jobs fall back to small.en, follow-up STT-09); RSS < 1.5 GB. | iPhone 15 Pro / Pixel 8 Pro | iOS 18.x / Android 15 | ⏳ | | |

## Notes / evidence
Raw JSON per device under `docs/test-plans/device/evidence/STT-07/`; copy the medians into the
device-class columns of `docs/models.md`.
