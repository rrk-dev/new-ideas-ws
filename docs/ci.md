# CI

GitHub Actions (`.github/workflows/ci.yml`) is a thin wrapper: every job calls a script in
`tools/ci/`, so the same commands run locally (`bash tools/ci/<script>.sh`) or on another runner.

| Job | Script(s) | Notes |
|---|---|---|
| `static` | `setup.sh`, `format.sh`, `analyze.sh`, `check_codegen.sh`, `check_egress.sh`, `run_slot.sh check_recording_policy.sh SEC-09`, `tasks.py validate` | `analyze.sh` runs `flutter analyze` **and** `dart analyze` (riverpod_lint only reports in the latter, ADR-FND-02) |
| `test` | `test.sh` | unit + widget tests, lcov uploaded; gate ≥ 80% lines over `lib/core/**` and `lib/**/domain/**` (`check_coverage.py`) |
| `task-gate` | `pytest tools/ci/tests`, `tasks.py verify --all-done --run` | independent-verification gate: every `done` task keeps tagged tests, report, PASS rows |
| `android` | `build_android.sh` | debug dev-flavor APK (Gradle builds `libvv_native.so` with the pinned NDK; `check_apk_native.sh` asserts it is in the APK), uploaded as `android-dev-debug-apk` |
| `ios` | `build_ios.sh` | `native/build.sh ios` first (xcframework), then the unsigned dev-flavor build, uploaded as `ios-dev-unsigned-app` |
| `native-host` | `native_host.sh` | `native/build.sh host` (ctest: smoke + exports) and the Dart FFI test against the built library, ccache keyed on the submodule pins |

Slot (`run_slot.sh`, currently only `check_recording_policy.sh`) run `tools/ci/<script>` if present, otherwise emit a visible warning and pass.
Delivering the script is what activates the check — no workflow change needed.

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
