# STT-01 — whisper.cpp iOS Build (Metal / Core ML)

**Workstream:** STT | **Phase:** 2 (Weeks 4–7) | **Size:** M | **Depends on:** FND-06 | **Source:** §4.2, §5 Phase 2
**Status:** review
**Skills:** vv-task-workflow, vv-native-build, vv-whisper-stt, vv-benchmark-eval, vv-decision-records, vv-testing

## Goal
whisper.cpp runs on iOS with GPU acceleration.

## Scope
- [x] Build whisper.cpp into the shared xcframework with `GGML_METAL=ON`. (config in `native/build.sh ios` / `native/CMakeLists.txt`; compile needs Xcode → device rows)
- [x] Evaluate Core ML encoder (`WHISPER_COREML=ON`, ANE) vs Metal-only: speed, first-run compile time, extra model download size (`-encoder.mlmodelc`). (host measured; iPhone rows ⏳)
- [x] Metal shader library embedded; verify on A13 (iPhone 11) through A18. (`GGML_METAL_EMBED_LIBRARY=ON`, host ctest `stt_backend_gpu`; A13–A18 runs ⏳ device rows)
- [x] Note in the ADR that master plan §3.1.2's ONNX/ExecuTorch STT alternatives were considered and why whisper.cpp was kept (or spike them if Core ML/Metal results are poor).
- [x] CPU-only fallback path (needed for background — FND-08). (`use_gpu=false`; host ctest `stt_backend_cpu`; exposed to Dart in STT-03)

## Acceptance Criteria
- `whisper-base.en` Q8 transcribes 60 s of audio in < 6 s on iPhone 13 (Metal); numbers recorded for iPhone 11.
- Decision on Core ML encoder documented with benchmark data.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-01-whisper-ios · **Date:** 2026-10-13
- **Summary:** iOS whisper build configuration on the FND-06 superproject: Metal with embedded
  shaders (`native/build.sh ios`), new opt-in `VV_WHISPER_COREML` CMake option (→
  `WHISPER_COREML` + `WHISPER_COREML_ALLOW_FALLBACK`, forwarded by `VV_WHISPER_COREML=ON
  native/build.sh ios`), CPU-only path via `use_gpu=false`. Host tool
  `native/tests/stt_backends.cpp` (ctests `stt_backend_cpu`, `stt_backend_gpu`,
  `stt_backend_coreml-fallback`; skipped without `VV_TEST_MODELS_DIR`) + bench
  `tools/bench/stt_host_bench.sh` (raw: `tools/bench/results/2026-10-13-stt-host-backends.jsonl`).
  Shared internal WAV reader `native/bridge/vv_wav.h`. Static config tests
  `tools/ci/tests/test_stt_native_build.py`. No Xcode/iPhone was available: the iOS build and all
  iPhone numbers are device rows.
- **Host numbers (M3 Pro, base.en q8_0, 60 s, greedy, 4 threads, 5 runs median):** Metal 1.03 s
  (RTF 0.017), Core ML enc + Metal 1.10 s, CPU-only 4.98 s, Core ML enc + CPU 1.97 s; cold first
  load Metal 5.7 s, Core ML 10.6 s; Core ML companion +39 MB (base.en); dylib +7.6 KB.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/STT-01.md
  - AC2: ⏳ artifact: docs/adr/ADR-STT-01-ios-coreml-vs-metal.md; test: [STT-01/AC2]; device: docs/test-plans/device/STT-01.md
- **Decisions:** ADR-STT-01-ios-coreml-vs-metal (Proposed: Metal-only for v1).
- **Follow-ups:** CI native-host job should run `tools/ci/fetch_test_models.sh ggml-tiny.en.bin jfk.wav`
  and export `VV_TEST_MODELS_DIR` so the `stt_backend_*` ctests run instead of skipping (CI owner);
  iOS 16.0 vs 16.4 minimum (ADR-FND-06, user).


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ⏳ iPhone 13 <6 s for 60 s base.en Q8, iPhone 11 numbers and background CPU rows have explicit steps but no results. Host CPU/Metal keyword ctests passed; they do not establish iPhone performance.
  - AC2: ✅ tagged pytest checks the Proposed ADR and measured Metal/Core ML raw labels/numbers. Read ADR, raw benchmark artifact and Core ML build flags against whisper v1.9.5; device warm/cold/companion fallback rows remain ⏳.
- **Mutation sanity check:** Disabled WHISPER_COREML_ALLOW_FALLBACK in native/CMakeLists.txt: the Core ML configuration test failed (1 failed); restored with git checkout.
- **Adversarial checks:** CPU-only and Metal host transcription passed. Missing Core ML companion cannot be tested in the default non-Core-ML build (ctest explicitly skipped). iPhone measurements were not inferred from Mac numbers.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/STT-01.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:** none in the verified host implementation; physical acceptance remains pending.
- **Pending for done:** STT-01: FAIL AC1: still pending (⏳) — cannot be done | STT-01: FAIL AC1: device row in docs/test-plans/device/STT-01.md has no PASS result with a date | STT-01: FAIL AC2: still pending (⏳) — cannot be done | STT-01: FAIL AC2: device row in docs/test-plans/device/STT-01.md has no PASS result with a date | STT-01: FAIL dependency FND-06 is not done | STT-01: FAIL FND-03 (CI / test framework) must be done before any non-bootstrap task | STT-01: FAIL QA-01 (CI / test framework) must be done before any non-bootstrap task | refusing to set STT-01 to done: 7 problem(s) (see vv-task-verify)
