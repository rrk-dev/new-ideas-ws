# REL-01 — Release Build & Signing Pipeline

**Workstream:** Release | **Phase:** 4 | **Size:** M | **Depends on:** FND-03 | **Source:** §5 Phase 4 (release build pipelines)
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release, vv-testing

## Goal
Reproducible, signed release builds shipped to stores from CI.

## Scope
- [x] Fastlane (or equivalent) lanes for iOS (match/App Store Connect API key) and Android (Play upload key, AAB).
- [x] Versioning scheme and automatic build numbers; changelog generation.
- [x] Dart obfuscation + `--split-debug-info`; symbols stored privately (not uploaded to third-party crash services).
- [x] Release checklist (SEC-06, license screen, version bump, smoke test).
- [x] Secrets management in CI.

## Acceptance Criteria
- Tagging a release produces signed builds uploaded to TestFlight and Play internal track automatically.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/REL-01-release-pipeline · **Date:** 2026-10-13
- **Summary:** Tag `vX.Y.Z` → `.github/workflows/release.yml` (new file; `ci.yml` untouched):
  `prepare` (tag must equal pubspec version, build number, changelog) → `android`
  (`bundle exec fastlane android internal`: upload-key signed prod AAB → Play internal track) and
  `ios` (`bundle exec fastlane ios beta`: App Store Connect API key + `match` readonly →
  obfuscated prod IPA → TestFlight), both behind the `release` GitHub environment.
  Key files: `app/ios/fastlane/{Fastfile,Appfile,Matchfile}`, `app/android/fastlane/{Fastfile,Appfile}`,
  `app/{ios,android}/Gemfile`, `app/android/signing.gradle` (+1 `apply(from=…)` line in
  `app/android/app/build.gradle.kts`; reads `key.properties`, debug fallback locally, hard fail when
  `VV_REQUIRE_RELEASE_SIGNING=true`), `tools/release/build_release.sh` (`--obfuscate
  --split-debug-info`, obfuscation map, unstripped `libvv_native.so` / dSYMs, `SHA256SUMS` →
  `app/build/release-symbols/<platform>/`, uploaded only as private workflow artifacts; IPA export
  with `uploadSymbols=false`), `tools/release/version.py` (SemVer in pubspec; build number =
  `GITHUB_RUN_NUMBER + VV_BUILD_NUMBER_OFFSET`, monotonic, shared by both stores),
  `tools/release/changelog.py` (Conventional Commits → Markdown + ≤ 500-char store notes),
  `docs/release-checklist.md`, `docs/release-secrets.md` (12 secrets + 1 variable).
  **Not executed:** fastlane, Xcode and the Android SDK are not installed on the authoring machine —
  the Fastfiles, `signing.gradle` and `release.yml` were syntax-checked (`ruby -c`, `bash -n`) and
  statically tested only; the first tagged run on GitHub Actions is the real test.
- **Gates:** `python3 -m pytest tools/ci/tests tools/release/tests -q` 58 passed, 1 skipped;
  app: build_runner (no diff), `dart format` 0 changed, `flutter analyze` 0 issues, `flutter test`
  210 passed / 8 skipped; `check_recording_policy.sh` OK; `check_egress.sh` OK; `tasks.py validate` 0 problems.
- **Acceptance evidence:**
  - AC1: ⏳ test: [REL-01/AC1]; device: docs/test-plans/device/REL-01.md; ci: first tagged release run on GitHub Actions
- **Decisions:** no new runtime dependency. Choices documented in `docs/release-checklist.md` /
  `docs/release-secrets.md`: GitHub Actions (remote is GitHub), fastlane + match (git storage) as
  in `vv-ci-release`; dSYMs are *not* uploaded to Apple (`uploadSymbols=false`) to keep all
  symbols private — switch on if App Store Connect symbolication is wanted.
- **Follow-ups:**
  - Commit `app/ios/Gemfile.lock` and `app/android/Gemfile.lock` after the first `bundle install`
    (fastlane pinned `~> 2.228` only).
  - Pin `ruby/setup-ruby` (currently `@v1`) and confirm `actions/download-artifact@v7.0.0` on the
    first run; pin all release actions to commit SHAs.
  - Workflow artifacts expire after 90 days: symbols must be copied to the private release archive
    each release (checklist item) — a dedicated private storage target is a follow-up decision.
  - Gradle signing lives in `app/android/signing.gradle` (Groovy, applied from the Kotlin script) to
    avoid conflicts with the Gradle owner; fold it into `build.gradle.kts` later if preferred.
  - REL-04 (external beta groups / closed testing) promotes these builds; REL-03 adds `size_check.sh`
    to the release job.
