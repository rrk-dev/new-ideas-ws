# FND-03 — Continuous Integration Pipeline

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** Gap (no CI defined)
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release, vv-testing, vv-privacy-security, vv-native-build, vv-ffi-bridge

## Notes
- This is a **bootstrap** task: nothing outside FND-01/02/03, QA-01, QA-05 can be verified `done` until it is.

## Goal
Every change is formatted, analyzed, tested and built for both platforms, including native C/C++ libraries.

## Scope
- [x] CI jobs: format check, analyze, unit + widget tests with coverage report.
- [x] Android build job producing a debug APK (`fvm flutter build apk --flavor dev -t lib/main_dev.dart`). FND-06 later adds the native libs (`libvv_native.so`) to this job.
- [x] iOS build job on macOS runner producing an unsigned build (FND-06 adds `vv_native.xcframework`).
- [x] Cache Flutter pub, Gradle, CocoaPods/SPM and native build artifacts (ccache).
- [x] `tools/ci/check_egress.sh` (minimal version; SEC-02 extends it) as a PR job, plus a job slot for `tools/ci/check_recording_policy.sh` (script delivered by SEC-09).
- [x] `tasks.py validate` and `tasks.py verify --all-done --run` as blocking PR jobs (independent-verification gate).
- [x] Job slots/scripts for native host smoke tests (`ci/native_host.sh`) — filled in by FND-06.
- [~] deferred → admin action: Branch protection: CI must pass before merge. (command + required checks documented in `docs/ci.md`; needs repo admin, not applied)

## Acceptance Criteria
- A PR triggers all jobs; total pipeline time < 25 min with warm caches.
- Failing lint/test blocks merge.
- A PR that sets a task to `done` without a passing `tasks.py verify` (e.g. missing tagged test or verification report) fails CI (demonstrated on a test branch).
- Build artifacts downloadable from CI for QA.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-03-ci-pipeline (stacked on FND-02 → FND-01) · **Date:** 2026-10-12
- **Summary:** GitHub Actions workflow `.github/workflows/ci.yml` (jobs `static`, `test`, `task-gate`, `android`,
  `ios`, `native-host`) wrapping scripts in `tools/ci/` (`setup`, `format`, `analyze` (flutter + dart analyze),
  `test` + `check_coverage.py` (≥ 80% over core/domain), `check_codegen`, `check_egress` (minimal), `build_android`,
  `build_ios`, `run_slot` for `check_recording_policy.sh` (SEC-09) and `native_host.sh` (FND-06)). `tasks.py validate`
  and `verify --all-done --run` are blocking jobs. Caches for fvm/pub/Gradle/Pods/ccache; artifacts uploaded
  (APK, unsigned iOS app zip, lcov). Added `app/test/unit/providers_test.dart` (FND-02 code) to lift core
  coverage 77.8% → 92.1% so the gate passes honestly. Docs: `docs/ci.md`.
  Not done / unverified: the workflow has never run on GitHub; Android/iOS builds were not run locally (no SDK/Xcode);
  branch protection needs a repo admin; slots only warn until SEC-09 / FND-06 deliver their scripts.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/FND-03.md
  - AC2: ⏳ test: [FND-03/AC2]; device: docs/test-plans/device/FND-03.md
  - AC3: ⏳ test: [FND-03/AC3]; device: docs/test-plans/device/FND-03.md
  - AC4: ⏳ device: docs/test-plans/device/FND-03.md
- **Decisions:** none (GitHub Actions chosen from the `origin` remote; scripts stay runner-agnostic)
- **Follow-ups:** apply branch protection (repo admin); FND-06 to fill `native_host.sh` and add native libs to the Android/iOS jobs; SEC-09 to deliver `check_recording_policy.sh`; SEC-02 to extend `check_egress.sh`
