# Verification on GitHub Actions — FND-03 Continuous Integration Pipeline

These rows need a real CI run (the "device" is the GitHub-hosted runners). The pipeline has never
run yet: it was authored without pushing a PR.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-03/AC1] | 1. Open a PR from a task branch. 2. Run it twice so caches are warm. 3. Read the workflow run duration. | All six jobs (`static`, `test`, `task-gate`, `android`, `ios`, `native-host`) start; the second run finishes in < 25 min wall clock. | GitHub Actions ubuntu-latest + macos-latest | runner images | | | |
| [FND-03/AC2] | 1. Apply branch protection from `docs/ci.md`. 2. Push a PR with an unformatted Dart file; another with a failing test. | `static` / `test` fail and the merge button is blocked. | GitHub Actions | runner images | | | |
| [FND-03/AC3] | 1. On a throwaway branch edit a task to `**Status:** done` with no `## Verification Report`. 2. Open a PR. | `task-gate` fails with `missing '## Verification Report'`; PR cannot merge. | GitHub Actions | runner images | | | |
| [FND-03/AC4] | 1. Open the run summary of a green PR run. 2. Download `android-dev-debug-apk`, `ios-dev-unsigned-app` and `coverage-lcov`. | Artifacts are present and the APK installs on an arm64 Android device/emulator. | GitHub Actions + arm64 Android | runner images | | | |

## Notes / evidence
Locally verified (no Xcode / Android SDK on the authoring machine): `format.sh`, `analyze.sh`,
`test.sh` (92.1% coverage over gated files), `check_codegen.sh`, `check_egress.sh` all pass, and
`python3 -m pytest tools/ci/tests` passes. `build_android.sh` and `build_ios.sh` have not run
anywhere yet — the first CI run is also the first compile of the Android/iOS flavors from FND-01.
