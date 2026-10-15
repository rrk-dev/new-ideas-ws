# FND-06 — Native C/C++ Build Infrastructure

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** §4.2, §5 Phase 2
**Status:** review
**Skills:** vv-task-workflow, vv-native-build, vv-ffi-bridge, vv-decision-records, vv-testing

## Goal
Reproducible builds of `whisper.cpp` and `llama.cpp` (shared `ggml`) for both platforms, consumed by Flutter via FFI.

## Scope
- [x] Vendor `whisper.cpp` and `llama.cpp` as git submodules pinned to specific commits; document upgrade procedure.
- [x] Resolve duplicate `ggml` symbols (both projects embed ggml) — build a single shared ggml or namespace them.
- [x] Android: CMake via Gradle `externalNativeBuild`, NDK version pinned, arm64-v8a, `-O3`, NEON/dotprod/i8mm flags.
- [x] iOS: build script producing `.xcframework` (device + simulator), Metal shaders embedded (`GGML_METAL_EMBED_LIBRARY`).
- [x] Thin C wrapper (`vv_bridge.h`) exposing a stable C ABI for Dart FFI; generate Dart bindings with `ffigen`.
- [x] Packaged as an internal Flutter FFI plugin (`packages/vv_native`).
- [x] Extend CI (FND-03): NDK-pinned native build in the Android job (APK contains `libvv_native.so`), `vv_native.xcframework` in the iOS job, `ci/native_host.sh` host build + C smoke tests with ccache.

## Acceptance Criteria
- Clean checkout → single command builds both platform libraries.
- A Dart test calls a trivial bridge function (`vv_version()`) on device for both platforms.
- Binary size of native libs recorded (input to REL-03).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-06-native-build (stacked on FND-03 → FND-02 → FND-01) · **Date:** 2026-10-12
- **Summary:** Submodules `native/whisper.cpp` (v1.9.5) and `native/llama.cpp` (v0.6.0) pinned (`native/VERSIONS.md`, upgrade
  procedure included). `native/CMakeLists.txt` builds ONE ggml (their trees are identical at the pins) linked statically into
  one `vv_native` shared library exporting only `vv_*`; Android knobs (NDK r28c, arm64, `-O3`, 16 KB link flags,
  `VV_ANDROID_CPU_ARCH`) and iOS framework packaging. `native/build.sh {host|android|ios|all}`. C ABI `native/bridge/vv_bridge.h`
  (`vv_abi_version`, `vv_version`, whisper/ggml versions, system info). `packages/vv_native`: ffigen bindings, loader with ABI
  handshake, Gradle→CMake (Android), podspec vending the xcframework (iOS), host Dart test; on-device test
  `app/integration_test/native_bridge_test.dart`. CI: `native_host.sh`, APK `libvv_native.so` check, xcframework before the iOS
  build, ccache keyed on pins. ADR-FND-06 (Proposed).
  **Verified locally (macOS, host only):** clean `native/build.sh host` + ctest (`vv_smoke`, `vv_exports`), Dart FFI host test,
  bindings drift check. **Not verified:** Android build/16 KB alignment/APK contents (no NDK), iOS xcframework (no Xcode), on-device
  `vv_version()`, mobile binary sizes; the Gradle/podspec glue has never been compiled.
- **Acceptance evidence:**
  - AC1: ⏳ test: [FND-06/AC1]; device: docs/test-plans/device/FND-06.md
  - AC2: ⏳ test: [FND-06/AC2]; device: docs/test-plans/device/FND-06.md
  - AC3: ⏳ artifact: native/VERSIONS.md; device: docs/test-plans/device/FND-06.md
- **Decisions:** ADR-FND-06-native-build (Proposed: iOS min 16.0 vs 16.4, Android CPU baseline, packaging)
- **Follow-ups:** user decision on iOS minimum (16.0 vs 16.4); CPU-variant dispatch + GPU backends (STT-02/LLM-03); `vv_jsg` (LLM-05); apply `native-host`/`android`/`ios` as required checks


## Verification Report — historical Cursor report (2026-10-13)
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-13 · **Commit:** 87963175263cf3aba56fc55cca584d490ce26a6d
- **Verdict:** FAIL
- **Gates:** format ✅ · analyze ✅ (no issues) · flutter tests ✅ (21 passed, coverage 94.4%) · native host smoke ✅ (`native/build.sh host`, ctest `vv_smoke` and `vv_exports` passed, `libvv_native.dylib` 6507968 bytes) after `git submodule update --init` · egress ✅ · recording policy n/a · CI run: local fresh worktree. Android and iOS builds not run (no NDK, no Xcode).
- **Acceptance criteria:**
  - AC1: ❌ `[FND-06/AC1]` fails on a checkout without submodules. `native/build.sh bogus` exits 2 because `check_submodules` runs before the usage case, so the test expects exit 64 and does not get it. The same three pytest tests pass once submodules are present. `task-gate` checks out without `submodules: recursive` and runs `pytest tools/ci/tests`, so this fails that job.
  - AC2: ⏳ host Dart/C smoke passed. On-device `vv_version()` rows in `docs/test-plans/device/FND-06.md` have no PASS. Not re-run (no phone, no SDK).
  - AC3: ⏳ host size was printed. Android stripped `.so` and iOS slice sizes are not filled in. Not measured here.
- **Adversarial checks:** fresh worktree, no submodules, `pytest tools/ci/tests/test_native_build.py` → the usage test failed (exit 2 vs 64). After submodule init, host build and the same tests passed. Did not upload audio or open a network client.
- **Skill/rule compliance:** one shared library, `vv_*` ABI, pins recorded in `native/VERSIONS.md`. ADR-FND-06 is still Proposed (iOS 16.0 vs 16.4, CPU baseline). That matches the notes; it is not this FAIL.
- **Issues found:**
  1. Parse the target before `check_submodules` (or otherwise make `native/build.sh bogus` exit 64 without a populated submodule), and make `task-gate` able to run `tools/ci/tests` on its current checkout. Today that job fails.

## Follow-ups
- **CI fix (2026-10-12, Claude Code, branch `task/FND-06-fix-ci`):** red `task-gate` on main — the job checks out without
  submodules and `native/build.sh` checked submodules before parsing its argument, so `[FND-06/AC1]` got exit 2 instead of 64
  for `build.sh bogus`. `build.sh` now validates the target first (exit 64), then the toolchain (NDK / Xcode, exit 2), then
  cmake/ninja, then submodules (exit 2). Test unchanged. Red `android` job: `packages/vv_native/android/build.gradle` is Groovy
  but used the Kotlin-only `abiFilters += listOf("arm64-v8a")` (Groovy has no `listOf` → configuration failure) → now
  `abiFilters "arm64-v8a"`; dropped a trailing comma in `arguments(...)`; `tools/ci/build_android.sh` passes
  `--target-platform android-arm64` so the debug APK cannot contain x86_64/armv7 libs that `check_apk_native.sh` rejects.
  Unproven (CI must confirm): NDK 28.2.13676358 / SDK CMake 3.22.1 auto-download on the runner, 25-min timeout for a
  debug ggml+llama+whisper build.

## Rework
- **Agent:** Claude Code · **Branch:** task/FND-06-rework · **Date:** 2026-10-13 — answers the Cursor FAIL report above.
  That report (commit `f3e95d6`) was dropped from this file by a later merge; it is restored above verbatim.
- **Issue 1 (`build.sh bogus` exits 2 without submodules; `task-gate` red):** fixed by merged PR #13
  (`task/FND-06-fix-ci`, merge `c519ef0`, contained in `main` `dd02452`): `native/build.sh` validates the target
  first (exit 64), then the toolchain (NDK/Xcode, exit 2), then cmake/ninja, then submodules (exit 2). The test was
  not changed. Re-run on a checkout **without** submodules (`git submodule status` → `-d812350… native/llama.cpp`,
  `-d1be6fd… native/whisper.cpp`, both empty), 2026-10-13, macOS:
  ```
  $ bash native/build.sh bogus; echo "exit=$?"
  usage: native/build.sh {host|android|ios|all}
  exit=64
  $ python3 -m pytest tools/ci/tests/test_native_build.py -v -rs -p no:cacheprovider
  test_FND_06_AC1_one_command_per_target_and_clear_toolchain_errors PASSED
  test_FND_06_AC1_submodule_pins_match_versions_doc PASSED
  test_FND_06_AC1_single_shared_ggml_trees_match SKIPPED (submodules not checked out)
  2 passed, 1 skipped in 0.52s
  ```
  The remaining `task-gate` and `android` CI failures on `main` are tracked on branch `fix/ci-task-gate-android`
  (CI files, not FND-06 code).
- **AC2 / AC3 (⏳ in the report):** unchanged — need the on-device `vv_version()` rows and the Android/iOS
  sizes from a machine with the NDK and Xcode (`docs/test-plans/device/FND-06.md`).


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ✅ host build from this fresh clone, shared ggml/export ctests and all three native-build pytest checks passed. Invalid target and missing NDK/Xcode return the documented errors. Mobile builds remain ⏳.
  - AC2: ✅ host Dart `[FND-06/AC2]` asserts version 0.1.0, ABI and nonempty runtime versions; device test read, not run. Both phone rows remain ⏳.
  - AC3: ⏳ versions/size artifact reviewed; this host dylib is 10,263,760 bytes. Android stripped and iOS slice sizes still require their toolchains.
- **Mutation sanity check:** Changed the invalid-target exit from 64 to 65: `test_FND_06_AC1_one_command_per_target_and_clear_toolchain_errors` failed (1 failed). Restored native/build.sh with git checkout; original three checks passed.
- **Adversarial checks:** Invalid target, missing toolchains, missing library/model, ABI handshake, symbol export isolation and ggml tree parity checked. The earlier Cursor issue is resolved at this SHA.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/FND-06.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
  The previous Cursor report body is preserved; its heading is marked historical so tasks.py parses this current report.
- **Issues found:** none in the verified host implementation; physical acceptance remains pending.
- **Pending for done:** FND-06: FAIL AC1: still pending (⏳) — cannot be done | FND-06: FAIL AC1: device row in docs/test-plans/device/FND-06.md has no PASS result with a date | FND-06: FAIL AC2: still pending (⏳) — cannot be done | FND-06: FAIL AC2: device row in docs/test-plans/device/FND-06.md has no PASS result with a date | FND-06: FAIL AC3: still pending (⏳) — cannot be done | FND-06: FAIL AC3: device row in docs/test-plans/device/FND-06.md has no PASS result with a date | FND-06: FAIL dependency FND-01 is not done | FND-06: FAIL FND-03 (CI / test framework) must be done before any non-bootstrap task | FND-06: FAIL QA-01 (CI / test framework) must be done before any non-bootstrap task | refusing to set FND-06 to done: 9 problem(s) (see vv-task-verify)
