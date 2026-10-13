# Device verification — LLM-02 llama.cpp iOS build (Metal)

Needs Xcode (not available when authored) and the iPhones below. Host (macOS, Metal) parts were
built and tested: `native/build.sh host` → ctest `vv_llm_backend`, `packages/vv_native` host FFI
tests, `app/test/unit/extraction/`.

**Setup (once per device):**
1. `git submodule update --init --recursive && native/build.sh ios` (copies the xcframework into
   `packages/vv_native/ios/Frameworks`).
2. Signing: the App ID needs the **Increased Memory Limit** capability (Runner.entitlements
   requests `com.apple.developer.kernel.increased-memory-limit`).
3. Model: `bash tools/ci/fetch_test_models.sh` does not carry the 3B/1B models; download the
   GGUFs (bartowski HF revisions, sha256 below) and copy them into the
   app's Documents directory (Xcode → Window → Devices → app → Download/Replace Container).
4. Nominal thermal state, airplane mode, unplugged, screen on (foreground run).

Commands (from `app/`), each prints `VV_LLM_BENCH …` lines + `VV_LLM_BENCH_MEDIAN {…}`; paste the
median line into "Notes / evidence" and the decode/prefill into ADR-LLM-01's device table.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-02/AC1] | `fvm flutter test integration_test/llm_ios_metal_test.dart --flavor dev -d <id> --plain-name "[LLM-02/AC1]" --dart-define=VV_LLM_BENCH_MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf --dart-define=VV_LLM_MIN_DECODE_TPS=15` | Passes: all 3 runs `used_gpu=true` (Metal, full offload, q8_0 KV), median decode ≥ 15 tok/s (2048-token prompt, 256 generated) | iPhone 15 Pro / 16 (VV-IOS-16) | iOS 18+ | | | |
| [LLM-02/AC1] | Same command without `VV_LLM_MIN_DECODE_TPS`, model `Llama-3.2-1B-Instruct-Q4_K_M.gguf`; then again with the 3B model if it loads | Numbers recorded (1B always; 3B "fits / jetsam" noted) — feeds LLM-07 tiering | iPhone 11 (VV-IOS-11) | iOS 16–18 | | | |
| [LLM-02/AC1] | Same 3B command with `--dart-define=VV_LLM_BENCH_GPU=0` (the background CPU path) | Passes with `used_gpu=false`; CPU decode tok/s recorded | iPhone 15 Pro / 16 | iOS 18+ | | | |
| [LLM-02/AC2] | `fvm flutter test integration_test/llm_ios_metal_test.dart --flavor dev -d <id> --plain-name "[LLM-02/AC2]" --dart-define=VV_LLM_BENCH_MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf` (4096-token prompt + 1024 generated, q8_0 KV). Watch Xcode console / Settings → Privacy → Analytics → JetsamEvent. | Test passes (process not killed); no new `JetsamEvent` report for the app; peak footprint in the median line | 6 GB iPhone: iPhone 14 / 13 Pro (VV-IOS-14) | iOS 17+ | | | |
| [LLM-02/AC2] | Repeat the AC2 command with `--dart-define=VV_LLM_BENCH_KVQ=0` (f16 KV) | Recorded for LLM-07 (expect higher footprint; may be killed — that is data, not a FAIL of AC2) | VV-IOS-14 | iOS 17+ | | | |

## Notes / evidence
Host reference (Apple M3 Pro, Metal, llama.cpp v0.6.0, 3B Q4_K_M, n = 1): 4164-token prompt +
1024 generated → q8_0 KV peak `phys_footprint` 538 MiB (f16 KV 814 MiB), prefill 745 tok/s,
decode 37.5 tok/s. Full host matrix (incl. CPU path): LLM-01 `tools/bench/results/2026-10-13-llm01-host.md`.

Models (HF `bartowski/Llama-3.2-{1B,3B}-Instruct-GGUF`, revisions `067b946c` / `5ab33fa9`):
- `Llama-3.2-3B-Instruct-Q4_K_M.gguf` sha256 `6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff`
- `Llama-3.2-1B-Instruct-Q4_K_M.gguf` sha256 `6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83`
