# REL-03 — App Binary Size Optimization

**Workstream:** Release | **Phase:** 4 | **Size:** S | **Depends on:** FND-06, MDL-02 | **Source:** §5 Phase 2 (avoid bloated app store binaries)
**Status:** todo
**Skills:** vv-task-workflow, vv-ci-release, vv-native-build, vv-testing

## Goal
Keep the store download small; all models delivered post-install.

## Scope
- [ ] Ship zero model weights in the binary (except optional tiny VAD model, few MB).
- [ ] Android App Bundle with ABI splits (arm64 only); strip native symbols; R8 shrinking.
- [ ] iOS: strip, dead-code stripping, bitcode n/a; verify Metal library size.
- [ ] Set budget (e.g., < 40 MB download) and CI size check.

## Acceptance Criteria
- Store download size under budget on both platforms; CI fails on > 10% regression.
