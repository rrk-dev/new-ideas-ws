# REL-01 — Release Build & Signing Pipeline

**Workstream:** Release | **Phase:** 4 | **Size:** M | **Depends on:** FND-03 | **Source:** §5 Phase 4 (release build pipelines)
**Status:** todo
**Skills:** vv-task-workflow, vv-ci-release, vv-testing

## Goal
Reproducible, signed release builds shipped to stores from CI.

## Scope
- [ ] Fastlane (or equivalent) lanes for iOS (match/App Store Connect API key) and Android (Play upload key, AAB).
- [ ] Versioning scheme and automatic build numbers; changelog generation.
- [ ] Dart obfuscation + `--split-debug-info`; symbols stored privately (not uploaded to third-party crash services).
- [ ] Release checklist (SEC-06, license screen, version bump, smoke test).
- [ ] Secrets management in CI.

## Acceptance Criteria
- Tagging a release produces signed builds uploaded to TestFlight and Play internal track automatically.
