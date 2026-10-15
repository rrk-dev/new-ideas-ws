# Device verification — LLM-04 LLM Dart FFI binding & inference service

Host-verified (macOS M3 Pro, Metal + CPU, SmolLM2-135M): ctest `vv_llm_engine`,
`packages/vv_native/test/llm_engine_host_test.dart`, `app/test/unit/extraction/llm_service_test.dart`,
`ffi_llm_runtime_host_test.dart`, `app/test/widget/llm_debug_screen_test.dart`. Cancel on the host:
0.1–1.3 ms from cancel() to on_done during decode; unload: ≤ 3 MiB above the warm baseline over 6
GPU/CPU load cycles.

**Known risk to check on device:** llama.cpp's abort callback only interrupts CPU graphs; on Metal
a prefill slice (`n_batch` = 512 tokens) runs to completion before the cancel flag is seen. A 3B
model on an older iPhone may need > 500 ms per slice — the prefill row measures this. If it fails,
lower `n_batch` for cancellable runs (follow-up in LLM-04 notes).

Model on device: see LLM-02 / LLM-03 device docs (Documents dir). Commands from `app/`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-04/AC1] | `fvm flutter run --flavor dev -t lib/main_dev.dart -d <id> --dart-define=VV_DEV_LLM_MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf` → Settings → "LLM debug (dev)" → Generate, watch text, tap Cancel mid-stream | Text appears incrementally (not all at once); status "cancelled" right after the tap | iPhone (any, iOS 16+) | iOS 16+ | | | |
| [LLM-04/AC1] | Same on Android | Same | arm64 Android | API 26+ | | | |
| [LLM-04/AC1] | `fvm flutter test integration_test/llm_engine_test.dart --flavor dev -d <id> --plain-name "[LLM-04/AC1]" --dart-define=VV_LLM_BENCH_MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf` | Passes: `VV_LLM_CANCEL decode_ms` and `prefill_ms` both < 500 | iPhone 11 (VV-IOS-11, worst case Metal) + VV-AND-7 | iOS 16+ / Android 13+ | | | |
| [LLM-04/AC3] | Same file, `--plain-name "[LLM-04/AC3]"` with the 1B model, then with `--dart-define=VV_LLM_BENCH_GPU=0` | Passes: `VV_LLM_UNLOAD delta` < 50 MiB for GPU and CPU | iPhone + Android (any matrix device) | — | | | |
| [LLM-04/AC2] | Same file, `--plain-name "[LLM-04/AC2]"` | Passes (identical output for the same seed) | iPhone + Android | — | | | |
| [LLM-04/AC1] | Debug screen, start a long generation, press Home (iOS) | App keeps running; run restarts on CPU (status `done`, not `failed`); no GPU error crash | iPhone (VV-IOS-16) | iOS 18+ | | | |
| [LLM-04/AC1] | Debug screen with the 3B model, tap Generate and press Home **while the model is still loading** (before the first token) | Run completes on CPU (status `done`, backend CPU in the stats line); no Metal/GPU error, no crash | iPhone (VV-IOS-16) | iOS 18+ | | | |
