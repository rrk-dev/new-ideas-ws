# Device verification — STT-01 whisper.cpp iOS Build (Metal / Core ML)

Authored without Xcode or an iPhone: the iOS build configuration (`native/build.sh ios`,
`VV_WHISPER_COREML`) is written but not compiled; host (macOS, Metal + Core ML) was built and
measured — see `docs/adr/ADR-STT-01-ios-coreml-vs-metal.md`.

**Bench method (all rows):** `VV_WHISPER_COREML={OFF|ON} native/build.sh ios`, install the app
(dev flavor) with the STT-03 engine, seed `ggml-base.en-q8_0.bin` (and for Core ML rows
`ggml-base.en-encoder.mlmodelc` in the same folder), transcribe a 60 s 16 kHz mono clip
(`jfk.wav` tiled to 60 s, or a 60 s LibriSpeech clip), greedy, `n_threads` = performance cores.
≥ 3 runs after one warm-up, report median and min/max of `whisper_full` wall time; record
thermal state at start (nominal), iOS version, build commit. Put raw numbers in
`docs/test-plans/device/evidence/STT-01/`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-01/AC1] | Bench method, `VV_WHISPER_COREML=OFF` (Metal), app in foreground. | 60 s base.en Q8 transcribed in **< 6 s** (median); log shows `using MTL` backend. | iPhone 13 | iOS 17/18 | | | |
| [STT-01/AC1] | Same as above. | Numbers recorded (no threshold); runs without crash on A13. | iPhone 11 | iOS 17/18 | | | |
| [STT-01/AC1] | Bench method with `use_gpu=false` (CPU-only fallback), foreground and then with the app backgrounded (background audio session active). | Completes on CPU, transcript matches the Metal run's keywords; no Metal command buffers submitted while backgrounded (no `kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`). | iPhone 13 | iOS 17/18 | | | |
| [STT-01/AC2] | Bench method with `VV_WHISPER_COREML=ON` + encoder companion: record first-ever load (cold ANE compile), warm load and warm `whisper_full`; repeat foreground (Metal decoder) and backgrounded (CPU decoder). | Numbers recorded next to the Metal rows; ADR-STT-01 updated with them and moved to Accepted (or superseded). | iPhone 13 and iPhone 11 | iOS 17/18 | | | |
| [STT-01/AC2] | Core ML build **without** the companion file. | Init succeeds via fallback (log `failed to load Core ML model`), transcript correct. | any iPhone | iOS 16+ | | | |

## Notes / evidence
Host results (M3 Pro, macOS 27.0.1): `tools/bench/results/2026-10-13-stt-host-backends.jsonl`;
host ctests `stt_backend_cpu`, `stt_backend_gpu` (Metal, embedded shader library),
`stt_backend_coreml-fallback` (with `-DVV_WHISPER_COREML=ON`) pass.
