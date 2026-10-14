# Device verification — STT-02 whisper.cpp Android Build (NDK / Vulkan)

Authored without an Android NDK or device: the Android build configuration
(`VV_GGML_BACKEND_DL`, `VV_GGML_VULKAN`, `VV_GGML_OPENCL` in `native/CMakeLists.txt`, forwarded by
`native/build.sh android`) is written but not compiled. The loader/policy mechanism is verified on
the macOS host — see `docs/adr/ADR-STT-02-android-backends.md`.

**Builds:** (S) default static: `native/build.sh android`; (D) runtime CPU variants:
`VV_GGML_BACKEND_DL=ON native/build.sh android`; (V)/(O) add `VV_GGML_VULKAN=ON` /
`VV_GGML_OPENCL=ON` to (D) (needs glslc / OpenCL headers + ICD loader).
**Bench method:** STT-03 engine (or `stt_backends bench` pushed via `adb` with the modules next to
it), `ggml-base.en-q8_0.bin` and `ggml-small.en-q5_1.bin`, 60 s 16 kHz clip (`jfk.wav` tiled or a
LibriSpeech clip), greedy, n_threads = 0 (bridge default: performance cores capped at 4), plus a 2/4/6/8 sweep on
one device; ≥ 3 runs after a warm-up, median + min/max; start at nominal thermal status
(`dumpsys thermalservice`), screen on, airplane mode. Raw data →
`docs/test-plans/device/evidence/STT-02/`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-02/AC1] | Bench method with builds (S), (D), (V), (O); record RTF per backend and which CPU variant was loaded (`vv_backends_describe` / logcat `load_backend`). | Table of RTF per backend; (D) ≥ (S) speed; no SIGILL. | Snapdragon 8 Gen 2 (e.g. Galaxy S23) | Android 14/15 | | | |
| [STT-02/AC1] | Same as above. | Same. | Snapdragon 8 Gen 3 (e.g. Galaxy S24 / OnePlus 12) | Android 14/15 | | | |
| [STT-02/AC1] | Same as above + thread sweep 2/4/6/8. | Same; best thread count recorded. | Snapdragon 7-series (e.g. 7 Gen 1 / 7s Gen 2) | Android 13+ | | | |
| [STT-02/AC2] | Build (D)+(V): app with **shipped** allowlist (empty) → transcribe jfk; then force the GPU on (debug override of `GpuRules`) → transcribe again; kill the app during the first GPU transcription and relaunch. | Shipped config uses CPU and never dlopens `libggml-vulkan.so`; forced Vulkan either works or fails over to CPU without a crash; after the kill, `GpuTrialGuard` reports Vulkan as crashed and the next run uses CPU. | Mali device (e.g. Pixel 8 / Galaxy A55 / Dimensity) | Android 14/15 | | | |
| [STT-02/AC2] | Build (D): APK listing (`unzip -l`) and `llvm-objdump -p` for every packaged `.so`; install on the oldest matrix device (armv8.0/8.2, no dotprod if available) and transcribe. | APK contains `libvv_native.so`, `libggml*.so`, `libggml-cpu-android_*.so`, `libc++_shared.so`, all LOAD segments `2**14`; oldest device loads `android_armv8.0_1` (or 8.2_1) and transcribes — no SIGILL. | oldest arm64 device in `docs/device-matrix.md` | API 26+ | | | |
| [STT-02/AC2] | Background: start a transcription, send the app to background (foreground service active). | Policy returns CPU (`reason: background`) for new contexts; no GPU module is used while backgrounded. | any Android device | Android 14/15 | | | |

## Notes / evidence
Host (M3 Pro, macOS 27.0.1): ctests `vv_backends_{cores,cpu-only,gpu,missing-dir,describe}`,
`stt_backend_{cpu,gpu}` pass on `native/build/host` (static) and `native/build/host-dl`
(`-DVV_GGML_BACKEND_DL=ON`); Dart `[STT-02/AC2]` tests in `app/test/unit/backend_policy_test.dart`
and `packages/vv_native/test/vv_native_host_test.dart`.
