# Device verification — LLM-03 llama.cpp Android build (CPU / Vulkan / OpenCL)

Needs Android NDK r28c and the QA-05 Android phones; neither was available when authored.
Host-verified: ctest `vv_cpu` (big.LITTLE detection, HWCAP mapping, CPU guard),
`vv_llm_backend`, `app/test/unit/extraction/llm_backend_choice_test.dart` (shared STT/LLM policy,
ADR-INT-W2).

**Builds** (from a clean checkout, `git submodule update --init --recursive`):
- **B0 baseline**: `native/build.sh android` (armv8-a, FND-06 default).
- **B1 dotprod**: `VV_ANDROID_CPU_ARCH=armv8.2-a+dotprod native/build.sh android`.
- **B2 Vulkan / B3 OpenCL** (runtime-loaded modules only, ADR-STT-02 / ADR-INT-W2):
  `VV_GGML_BACKEND_DL=ON VV_GGML_VULKAN=ON native/build.sh android` /
  `VV_GGML_BACKEND_DL=ON VV_GGML_OPENCL=ON native/build.sh android` (the CPU variant is then
  picked at runtime — not combinable with `VV_ANDROID_CPU_ARCH`; the old `-DVV_ANDROID_VULKAN` /
  `-DVV_ANDROID_OPENCL` flags are deprecated aliases). OpenCL needs the Khronos headers +
  NDK-built ICD loader (`native/llama.cpp/docs/backend/OPENCL.md`).

**Model on device**: `adb push <gguf> /data/local/tmp/ && adb shell run-as com.vaultvoice.vaultvoice.dev cp /data/local/tmp/<gguf> app_flutter/`
(`app_flutter/` = the app's Documents dir; `run-as` starts in the app data dir) — or pass an absolute path via `VV_LLM_BENCH_MODEL`. Models:
`Llama-3.2-3B-Instruct-Q4_0.gguf` sha256 `4d491003bf6b470e4d04233824c5c939b76d6c81974ba17a3ff207343e1d8e85`,
`Llama-3.2-3B-Instruct-Q4_K_M.gguf` sha256 `6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff`
(HF `bartowski/Llama-3.2-3B-Instruct-GGUF` @ `5ab33fa9`).
Nominal thermal state, airplane mode, unplugged. Each run prints `VV_LLM_BENCH_MEDIAN {…}` —
paste it under Notes and into ADR-LLM-01 / ADR-LLM-03.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-03/AC1] | B1 installed. `cd app && fvm flutter test integration_test/llm_android_test.dart --flavor dev -d <id> --plain-name "[LLM-03/AC1]" --dart-define=VV_LLM_BENCH_MODEL=Llama-3.2-3B-Instruct-Q4_0.gguf --dart-define=VV_LLM_BENCH_GPU=0 --dart-define=VV_LLM_MIN_DECODE_TPS=10` | Passes: `cpuSupported`, threads = perf cores (6 on SD 8 Gen 3), median decode ≥ 10 tok/s | Snapdragon 8 Gen 3 / 8 Elite (VV-AND-FLG) | Android 14+ | | | |
| [LLM-03/AC1] | Same command with the Q4_K_M model, and both models on B0 | Numbers recorded (repack/dotprod gain, Q4_0 vs Q4_K_M) for ADR-LLM-03 / LLM-08 | VV-AND-FLG | Android 14+ | | | |
| [LLM-03/AC1] | B1, Q4_0 command without `VV_LLM_MIN_DECODE_TPS` | Numbers recorded | Snapdragon 7-series (VV-AND-7) | Android 13+ | | | |
| [LLM-03/AC2] | For **each** Android matrix device: install B2 (then B3 on Adreno), run `--plain-name "[LLM-03/AC2]"` with `VV_LLM_BENCH_MODEL=SmolLM2-135M-Instruct-Q8_0.gguf` (tools/ci/fetch_test_models.sh); if the app process dies, rerun the same command once | Test passes; no crash on the rerun; every GPU that crashed/fell back is logged `VV_LLM_GUARD … worked=false` or `recovered_from_crash=<key>` and is skipped as disabled; CPU run passes | VV-AND-FLG, VV-AND-7, VV-AND-PIX, VV-AND-4G | as installed | | | |
| [LLM-03/AC2] | B1 on every Android matrix device: `--plain-name "[LLM-03/AC1]"` (SmolLM2, no threshold) | `cpuSupported = true` (no SIGILL); fill the matrix "Dotprod" column from `VV_LLM_CPU features=(runtime, build)` | all Android matrix devices | as installed | | | |

## Notes / evidence
Host (macOS M3 Pro): `vv_cpu_test` → `cpu features runtime=0x7 build=0x3 perf_cores=6`.
Fake-sysfs perf-core counts: SD 8 Gen 3 → 6, SD 7 Gen 3 → 4, Tensor G3 → 5, single cluster → all.
