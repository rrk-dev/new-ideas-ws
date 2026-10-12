---
name: vv-ci-release
description: "CI and release engineering: CI scripts (format, analyze, tests, native smoke, egress and recording-policy checks, size), fastlane signing, versioning, obfuscation with private symbols, local crash capture, betas, store submission checklist."
---

# CI & Release

CI platform is not fixed by the plan (repo is on an internal Git server). Write jobs as
plain scripts in `tools/ci/*.sh` so any runner (GitHub Actions, GitLab CI, Jenkins) calls the
same commands; add the runner-specific YAML as a thin wrapper. Ask the user which CI system
before writing YAML if it isn't obvious from the remote.

## CI jobs (FND-03) — each a script under `tools/ci/`
| Script | Runs | Gate |
|---|---|---|
| `ci/format.sh` | `fvm dart format --set-exit-if-changed .` | PR |
| `ci/analyze.sh` | `fvm flutter analyze` (includes riverpod_lint plugin diagnostics) | PR |
| `ci/test.sh` | `fvm flutter test --coverage` + coverage threshold check | PR |
| `ci/native_host.sh` | `native/build.sh host` + ctest + Dart host FFI tests | PR |
| `ci/check_egress.sh` | forbidden network APIs outside gateway (`vv-privacy-security`) | PR |
| `ci/check_recording_policy.sh` | forbidden call-capture permissions/APIs/sources (SEC-09) on merged manifest + sources | PR + release |
| `ci/check_codegen.sh` | rerun build_runner/ffigen, `git diff --exit-code` | PR |
| `ci/build_android.sh` | `fvm flutter build apk --flavor dev -t lib/main_dev.dart --debug` (+ 16 KB check); upload APK as CI artifact | PR |
| `ci/build_ios.sh` | `fvm flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` (macOS runner); upload `.app` as artifact | PR |
| `ci/fetch_test_models.sh` | download `ggml-tiny.en.bin` + smallest test GGUF by sha256 into a CI cache (models are gitignored) | PR (cached) |
| `ci/markdownlint.sh` | `npx --yes markdownlint-cli2@<pinned>` with `docs/markdownlint.json` on golden outputs | PR |
| `ci/eval.sh` | PRF-09 eval (`make eval`) when `app/assets/profiles/**` or prompt code changes; nightly full run | PR (path filter) + nightly |
| `ci/size_check.sh` | compare release sizes vs `tools/ci/size-budget.json` | release |
| `ci/osv.sh` | `osv-scanner scan source -L app/pubspec.lock` (+ check submodule commits against upstream advisories) | nightly |
| `python3 .agents/skills/vv-task-workflow/scripts/tasks.py validate` | task files consistent | PR |
| `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify --all-done --run` | every `done` task still has its tagged tests / artifacts / device PASS rows, its verification report, and its Dart/pytest acceptance tests pass | PR (blocking) |
| `ci/device_suite.sh` | on-device `integration_test` suite on the device lab (oldest + newest device per platform) | nightly + before each phase gate |
Caches: pub cache, Gradle, CocoaPods, ccache for native (key: submodule commits + toolchain).
Pin: Flutter (FVM), Xcode version, NDK, CMake, JDK. Target ≤ 25 min warm.
Protect `main`: require all PR jobs green + one human review; no direct pushes.

## Signing & secrets (REL-01)
- fastlane in `app/ios/fastlane` and `app/android/fastlane`. iOS: `match` (private git repo or
  storage) or manual certs + App Store Connect **API key** (no Apple ID passwords in CI).
  Android: upload keystore in CI secret store; Play App Signing enabled.
- Secrets never in repo or logs; `set +x` around secret usage.

## Versioning
SemVer `MAJOR.MINOR.PATCH` in `pubspec.yaml`; build number = CI run number (monotonic across
both stores). Tag `vX.Y.Z` triggers release lanes. Changelog from Conventional Commits.

## Release build
```
fvm flutter build appbundle --flavor prod -t lib/main_prod.dart --obfuscate --split-debug-info=build/symbols/android
fvm flutter build ipa       --flavor prod -t lib/main_prod.dart --obfuscate --split-debug-info=build/symbols/ios
```
Keep `build/symbols/**`, native unstripped `.so`/dSYMs as **private** CI artifacts (retention ≥
app lifetime). Do not upload to third-party crash services.

## Crash reporting without cloud (REL-02)
- Dart: `FlutterError.onError` + `PlatformDispatcher.onError` → local crash file.
- Native: signal handlers (SIGSEGV/SIGABRT/SIGILL/SIGBUS) in the bridge writing a minimal
  report (signal, backtrace addresses, build id) to a pre-opened fd — async-signal-safe only.
  Consider a vetted minimal library (e.g. a KSCrash / Crashpad variant with uploads disabled)
  via ADR.
- Next launch: "The app crashed last time — share report?" → preview → share sheet/email.
  No upload endpoint of our own (egress policy) unless a future ADR adds one to the allowlist.
- Symbolicate with `flutter symbolize -i <trace> -d build/symbols/android/app.android-arm64.symbols`
  (one `.symbols` file per arch), `ndk-stack`, `atos`/
  `symbolicatecrash`. Document in `docs/crash-triage.md`.
- Baseline: App Store Connect / Play Console OS crash reports (user OS-level opt-in).

## Size budget (REL-03)
No model weights in binaries. Android: AAB, arm64 only, R8 (`minifyEnabled true` +
`shrinkResources true`), strip native. iOS: dead-code stripping, strip symbols in release.
Budget file `tools/ci/size-budget.json` (e.g. download < 40 MB each store); fail on > 10% growth.
Measure: Play Console / `bundletool get-size total`; App Store Connect App Thinning report
(`xcodebuild -exportArchive` with thinning).

## Beta (REL-04)
TestFlight external group + Play closed testing. In-app feedback = compose email/share with
optional diagnostics (FND-07). Exit criteria: crash-free sessions ≥ 99.5% (store consoles),
zero data-loss reports, ≥ 50 testers, extraction satisfaction survey target met.
Triage: each report → issue labelled `beta`, severity (S1 data loss/crash, S2 wrong output, S3 UX),
reproduced on the device matrix; S1 blocks release.

## Store submission (REL-05)
- Screenshots automated: integration tests that seed demo data (synthetic, no real people) +
  `fastlane snapshot` (iOS) / `screengrab` (Android) for required sizes.
- Metadata in `fastlane/metadata/**` (copy supplied by product; engineering owns structure).
- IAP products configured (`vv-licensing-iap`), privacy labels & manifest done (`vv-privacy-security`).
- Reviewer notes: state that the app never records phone/VoIP calls and records only after a
  user tap with visible indicators; how to test without an account, models download on first launch (sizes),
  why `audio` background mode / microphone FGS, demo audio file for import.
- Checklist `docs/release-checklist.md`: version bump, changelog, license screen, egress test
  report, size check, smoke test on oldest + newest device, symbols archived.
