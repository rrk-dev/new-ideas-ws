# ADR-STT-01 — Whisper on iOS: Metal-only vs Core ML (ANE) encoder

- **Status:** Proposed (host-measured on an M3 Pro Mac; iPhone 11 / iPhone 13 benchmarks pending —
  `docs/test-plans/device/STT-01.md`)
- **Date:** 2026-10-13
- **Task:** STT-01
- **Deciders:** Claude Code (implementer); pending independent verifier + device run
- **Supersedes:** —

## Context
STT-01 must run whisper.cpp on iOS with GPU acceleration: `whisper-base.en` Q8 must transcribe
60 s of audio in < 6 s on iPhone 13 (RTF < 0.10), with numbers recorded for iPhone 11 (A13, the
oldest supported Metal device in the matrix). whisper.cpp offers two Apple accelerators:

- **Metal** (ggml-metal) for encoder + decoder. Shader library embedded in the binary
  (`GGML_METAL_EMBED_LIBRARY=ON`, default when Metal is on — no `.metallib` to ship).
- **Core ML encoder** (`WHISPER_COREML=ON`): the encoder runs as a Core ML model
  (`MLComputeUnitsAll` → ANE/GPU/CPU chosen by Core ML; `src/coreml/whisper-encoder.mm`), the
  decoder still runs on ggml (Metal or CPU). Needs a per-model companion
  `<model minus .bin and -qX_Y>-encoder.mlmodelc` next to the `.bin` (quantized variants share the
  unquantized encoder: `ggml-base.en-q8_0.bin` → `ggml-base.en-encoder.mlmodelc`, verified in
  `whisper_get_coreml_path_encoder`, `src/whisper.cpp:3394`). First use on a device compiles the
  model for the ANE (slow, cached by the OS afterwards).

Constraints (AGENTS.md): offline, iOS 16+, models downloaded via the signed catalog (MDL-01),
STT and LLM never in memory together, **no GPU while backgrounded** (FND-08 / `vv-background-execution`)
so a CPU-only path is mandatory.

Master plan §3.1.2 also lists **ONNX Runtime** and **ExecuTorch** as STT runtimes. They were
considered and not spiked: whisper.cpp already gives Metal + optional ANE on iOS and NEON/GPU on
Android from one C++ code base, shares ggml with llama.cpp (one native stack, ADR-FND-06), and
reads the same `ggml` model files on both platforms. ONNX Runtime (CoreML / NNAPI execution
providers) and ExecuTorch (per-backend exported `.pte` programs) would each add a second native
runtime next to ggml plus their own model export/conversion and hosting pipeline (sizes and
current Whisper support not measured here — not needed unless whisper.cpp misses the budget).
Re-open only if the device numbers below miss the budget with both whisper.cpp options.

## Options
1. **Metal-only** — `GGML_METAL=ON`, embedded shaders, no Core ML. One model file per variant.
2. **Core ML encoder + Metal decoder, with fallback** — `VV_WHISPER_COREML=ON`
   (→ `WHISPER_COREML=ON` + `WHISPER_COREML_ALLOW_FALLBACK=ON`); the encoder companion is an
   optional catalog download; without it init falls back to the ggml (Metal/CPU) encoder.
3. **Core ML required** — `WHISPER_COREML=ON` without fallback (init fails when the companion is
   missing). Rejected up-front: a missing/corrupt companion would make STT unusable.

## Criteria (weights fixed before measuring)
| Criterion | Weight |
|---|---|
| Speed on target iPhones (warm RTF, foreground) | 30% |
| Background / CPU-only path speed | 15% |
| First-run latency (shader / ANE compile) | 15% |
| Download + storage size per model | 15% |
| Integration effort (catalog companions, unzip, two code paths to test) | 15% |
| Binary size / maintenance | 10% |

## Evidence
**Host only (indicative, not the acceptance device).** Apple M3 Pro (6P+6E), macOS 27.0.1,
Apple clang 21, CMake 4.4, Release; whisper.cpp v1.9.5 (`d1be6fd`), llama.cpp v0.6.0 ggml;
`ggml-base.en-q8_0.bin` (sha256 `a4d4a076…`) + `ggml-base.en-encoder.mlmodelc` (HF
`ggerganov/whisper.cpp@5359861`); `jfk.wav` tiled to 60 s; greedy, 4 threads, `no_context`;
5 runs, median (min–max); thermal nominal; other builds were running on the machine (CPU rows are
noisy). Tool: `tools/bench/stt_host_bench.sh` → `native/tests/stt_backends.cpp`;
raw: `tools/bench/results/2026-10-13-stt-host-backends.jsonl`.

| Metric (60 s audio) | Metal-only | Core ML enc + Metal dec | CPU-only (bg path) | Core ML enc + CPU dec |
|---|---|---|---|---|
| `whisper_full` wall, median (min–max) | **1.03 s** (0.85–1.47) | 1.10 s (0.86–1.17) | 4.98 s (4.65–5.69) | **1.97 s** (1.78–2.52) |
| RTF | 0.017 | 0.018 | 0.083 | 0.033 |
| Model load, warm | 0.22 s | 0.11 s | 0.21 s | 0.26 s |
| Model load, first ever (cold compile) | 5.7 s (Metal pipeline compile, first run after build) | 10.6 s (ANE compile) | 0.27 s | — |
| Extra download | — | +36 MB zip / 39 MB unpacked (base.en) | — | same |
| `libvv_native.dylib` size | 6,507,968 B | 6,515,568 B (+7.6 KB) | — | — |

Observations:
- Foreground: Core ML gives **no speed-up** over Metal on Apple GPU-class hardware for base.en;
  both are ~50× faster than real time on the host, far inside the 6 s budget if the iPhone 13 is
  even 5× slower.
- CPU-only (what we must use in background): the Core ML encoder is ~2.5× faster than the ggml CPU
  encoder. Whether Core ML may use the ANE while the app is backgrounded (GPU is not allowed;
  `MLComputeUnitsAll` lets Core ML choose) must be verified on device.
- Cold compile: Core ML's first load is ~2× Metal's first pipeline compile; both are one-time.
- Binary cost of compiling Core ML support in is negligible; the cost is the per-model companion
  download (base 39 MB, small ≈ 160+ MB) and a second encoder path to test.

## Decision (Proposed)
**Option 1, Metal-only, for v1** (`VV_WHISPER_COREML=OFF`, the default in `native/CMakeLists.txt`
and `native/build.sh ios`), with the CPU backend always compiled in for the background path
(`use_gpu=false` at context init — STT-03 exposes it as `vv_stt_init_params.use_gpu`).
Option 2 stays one flag away (`VV_WHISPER_COREML=ON native/build.sh ios`; fallback verified on the
host by the `stt_backend_coreml-fallback` ctest), so it can be adopted without code changes if the
device run shows that (a) Metal misses the iPhone 11 budget or (b) Core ML/ANE works while
backgrounded and materially speeds up background transcription.

To become **Accepted**: fill `docs/test-plans/device/STT-01.md` (iPhone 13 < 6 s for 60 s base.en Q8 on
Metal; iPhone 11 numbers; Metal vs Core ML warm/cold; background CPU vs Core ML).

## Consequences
- Positive: one model file per variant, no `.mlmodelc` unzip/companion logic in MDL-02, one
  encoder path to test; Metal shaders embedded (no extra bundle resource).
- Negative / risks: background transcription on CPU is ~5× slower than foreground Metal on the
  host (RTF 0.08 — still faster than real time); cold Metal pipeline compile on first STT run
  (~seconds) — mitigate with a warm-up during model install. iOS 16.0–16.3 Metal support is
  unverified (llama.cpp/whisper.cpp scripts target 16.4; ADR-FND-06 open item).
- Follow-up tasks: device benchmark (this task's device rows); if Option 2 is adopted later, MDL
  catalog `companions` entry for `-encoder.mlmodelc.zip` + unzip at install (MDL-02) and a
  per-device toggle in `DeviceCapabilities`.
