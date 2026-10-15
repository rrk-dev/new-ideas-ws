# REL-03 — App Binary Size Optimization

**Workstream:** Release | **Phase:** 4 | **Size:** S | **Depends on:** FND-06, MDL-02 | **Source:** §5 Phase 2 (avoid bloated app store binaries)
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release, vv-native-build, vv-testing

## Goal
Keep the store download small; all models delivered post-install.

## Scope
- [x] Ship zero model weights in the binary (except optional tiny VAD model, few MB).
- [x] Android App Bundle with ABI splits (arm64 only); strip native symbols; R8 shrinking.
- [x] iOS: strip, dead-code stripping, bitcode n/a; verify Metal library size.
- [x] Set budget (e.g., < 40 MB download) and CI size check.

## Acceptance Criteria
- Store download size under budget on both platforms; CI fails on > 10% regression.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/REL-03-app-size-optimization (base origin/main) ·
  **Date:** 2026-10-14
- **Summary:**
  - Budget `tools/ci/size-budget.json` (40 MiB download per store — PRODUCT-DECISION; iOS install
    ≤ 120 MiB; host bridge ≤ 15 MiB; max 10 % growth over a recorded baseline; bundled model
    ≤ 5 MiB and only a Silero VAD model).
  - Gate `tools/ci/size_check.py` + wrapper `tools/ci/size_check.sh`: measures the release
    AAB (`bundletool get-size total` for an arm64 device spec when available, else file size),
    IPA, `.app`, host library (stripped); fails on budget, > 10 % regression or model weights in
    any artifact / `app/assets`; `--update-baseline` records baselines.
  - Android: arm64-v8a only (existing `abiFilters` replacement), App Bundle via
    `tools/release/build_release.sh`, explicit R8 + resource shrinking in `build.gradle.kts`,
    AGP strips native libs (no `keepDebugSymbols`).
  - iOS: `DEAD_CODE_STRIPPING`, `STRIP_INSTALLED_PRODUCT`, `STRIP_STYLE = all` on the
    Release/Profile configurations (dSYM kept); `vv_native.framework` stripped at build time
    (`native/build.sh ios`: `DEPLOYMENT_POSTPROCESSING`, `STRIP_STYLE = non-global`, dSYM).
  - Measured host library: 9.80 MiB unstripped / 8.92 MiB stripped / 2.57 MiB gzip; the embedded
    Metal library is 51 % of it (verified, compresses well) —
    `tools/bench/results/2026-10-14-rel03-size.md`, row added to `native/VERSIONS.md`.
  - **CI steps to add (workflows not edited):** `.github/workflows/release.yml` — after the
    build in the `android` and `ios` jobs: `- run: bash tools/ci/size_check.sh`;
    `ci.yml` `native-host` job after `native_host.sh`: `- run: bash tools/ci/size_check.sh`
    (records/guards `host_native_lib_linux_mb`; first run with `--update-baseline`).
- **Acceptance evidence:**
  - AC1: ⏳ test: [REL-03/AC1]; device: docs/test-plans/device/REL-03.md; artifact: tools/bench/results/2026-10-14-rel03-size.md
- **Decisions:** none new (ADR-FND-06 build flags kept). PRODUCT-DECISION: 40 MiB budget.
- **Follow-ups:** add the CI steps above; record mobile baselines on the first release run.
  - Codex review 2026-10-15 (open): mobile size baselines in tools/ci/size-budget.json are null; record baselines and make release checks fail when missing
