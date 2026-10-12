# FND-03 — Continuous Integration Pipeline

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** Gap (no CI defined)
**Status:** todo
**Skills:** vv-task-workflow, vv-ci-release, vv-testing, vv-privacy-security, vv-native-build, vv-ffi-bridge

## Notes
- This is a **bootstrap** task: nothing outside FND-01/02/03, QA-01, QA-05 can be verified `done` until it is.

## Goal
Every change is formatted, analyzed, tested and built for both platforms, including native C/C++ libraries.

## Scope
- [ ] CI jobs: format check, analyze, unit + widget tests with coverage report.
- [ ] Android build job producing a debug APK (`fvm flutter build apk --flavor dev -t lib/main_dev.dart`). FND-06 later adds the native libs (`libvv_native.so`) to this job.
- [ ] iOS build job on macOS runner producing an unsigned build (FND-06 adds `vv_native.xcframework`).
- [ ] Cache Flutter pub, Gradle, CocoaPods/SPM and native build artifacts (ccache).
- [ ] `tools/ci/check_egress.sh` (minimal version; SEC-02 extends it) as a PR job, plus a job slot for `tools/ci/check_recording_policy.sh` (script delivered by SEC-09).
- [ ] `tasks.py validate` and `tasks.py verify --all-done --run` as blocking PR jobs (independent-verification gate).
- [ ] Job slots/scripts for native host smoke tests (`ci/native_host.sh`) — filled in by FND-06.
- [ ] Branch protection: CI must pass before merge.

## Acceptance Criteria
- A PR triggers all jobs; total pipeline time < 25 min with warm caches.
- Failing lint/test blocks merge.
- A PR that sets a task to `done` without a passing `tasks.py verify` (e.g. missing tagged test or verification report) fails CI (demonstrated on a test branch).
- Build artifacts downloadable from CI for QA.

## Follow-ups
- QA-05: do not add a Firebase Test Lab, Developer Device Platform, or BrowserStack job. Cloud farms are out of the lab plan (`docs/adr/ADR-QA-05-device-lab.md`, Proposed). On-device runs stay on the physical matrix.
