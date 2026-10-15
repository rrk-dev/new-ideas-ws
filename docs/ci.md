# CI

GitHub Actions (`.github/workflows/ci.yml`) is a thin wrapper: every job calls a script in
`tools/ci/`, so the same commands run locally (`bash tools/ci/<script>.sh`) or on another runner.

| Job | Script(s) | Notes |
|---|---|---|
| `static` | `setup.sh`, `format.sh`, `analyze.sh`, `check_codegen.sh`, `check_egress.sh`, `check_packages.sh` (SEC-02 package audit), `markdownlint.sh` (EXP-01 Markdown goldens, needs Node/npx), `run_slot.sh check_recording_policy.sh SEC-09`, `tasks.py validate` | `analyze.sh` runs `flutter analyze` **and** `dart analyze` (riverpod_lint only reports in the latter, ADR-FND-02) |
| `test` | `test.sh` | unit + widget tests, lcov uploaded; gate ≥ 80% lines over `lib/core/**` and `lib/**/domain/**` (`check_coverage.py`) |
| `task-gate` | `pytest tools/ci/tests`, `tasks.py verify --all-done --run` | independent-verification gate: every `done` task keeps tagged tests, report, PASS rows |
| `android` | `build_android.sh`, `check_recording_policy.sh --require-merged-manifest` | debug dev-flavor APK (Gradle builds `libvv_native.so` with the pinned NDK; `check_apk_native.sh` asserts it is in the APK and that no other ABI is packaged — the app's `ndk { abiFilters.clear(); … }` must replace the Flutter Gradle plugin's armeabi-v7a/arm64-v8a/x86_64 default, `+=` alone keeps all three), uploaded as `android-dev-debug-apk` |
| `ios` | `build_ios.sh` | `native/build.sh ios` first (xcframework), then the unsigned dev-flavor build, uploaded as `ios-dev-unsigned-app` |
| `native-host` | `native_host.sh`, `size_check.sh`, `fetch_test_models.sh`, `eval.sh` | `native/build.sh host` (ctest: smoke + exports) and the Dart FFI test against the built library, ccache keyed on the submodule pins; REL-03 host-library size budget; PRF-09 extraction eval with `--gate` only when profiles, the prompt builder, the eval data/runner or llama.cpp changed (`eval.sh` diffs against the base branch, so the checkout uses `fetch-depth: 0`; test models cached by `test-models.lock`; reports uploaded as `extraction-eval`) |

Release (`.github/workflows/release.yml`): the android and ios jobs run `size_check.sh` on the signed
AAB / IPA after the fastlane upload (REL-03 budget, no bundled models).

Integration wave 3 added the `check_packages.sh`, `markdownlint.sh`, `size_check.sh` and PRF-09
eval steps (ADR-INT-W3).

Slot (`run_slot.sh`, currently only `check_recording_policy.sh`) run `tools/ci/<script>` if present, otherwise emit a visible warning and pass.
Delivering the script is what activates the check — no workflow change needed.

Recording policy (SEC-09, `docs/adr/ADR-SEC-09-recording-policy.md`): `check_recording_policy.sh` is delivered, so the
`static` slot now enforces it on source manifests, `Info.plist`, entitlements and first-party sources; the `android` job
re-runs it on the merged manifest after the APK build (plugins included) and fails if no merged manifest is found.
Fixture tests: `tools/ci/tests/test_recording_policy.py`.

Pinned: Flutter via `.fvmrc` (FVM 4.3.1 in `setup.sh`), Temurin JDK 17, action versions by tag.
NDK `28.2.13676358` and CMake `3.22.1` are pinned in the Gradle files (`native/VERSIONS.md`). Xcode is the macOS runner default.

Caches: `~/fvm`, `~/.pub-cache`, Gradle, CocoaPods/Pods, ccache (keys use `.fvmrc`, `pubspec.lock`,
Gradle files, `.gitmodules`).

## Branch protection (needs repo admin — not applied by the pipeline)
`main` must require all jobs green and one human review, with no direct pushes:
```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["static", "test", "task-gate", "android", "ios", "native-host"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null
}
JSON
```

## Demonstrating the independent-verification gate (AC3)
Automated proof: `tools/ci/tests/test_ci_gates.py` copies the task files into a sandbox, flips a
task to `done` without a Verification Report and asserts `tasks.py verify --all-done` exits 1.
Live proof on a throwaway branch: set a task to `done` by hand (`tasks.py set` refuses), push, open a
PR, and observe `task-gate` fail; record the run URL in `docs/test-plans/device/FND-03.md`.
