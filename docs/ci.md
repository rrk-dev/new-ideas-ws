# CI

GitHub Actions (`.github/workflows/ci.yml`) is a thin wrapper: every job calls a script in
`tools/ci/`, so the same commands run locally (`bash tools/ci/<script>.sh`) or on another runner.

| Job | Script(s) | Notes |
|---|---|---|
| `static` | `setup.sh`, `format.sh`, `analyze.sh`, `check_codegen.sh`, `check_egress.sh`, `run_slot.sh check_recording_policy.sh SEC-09`, `tasks.py validate` | `analyze.sh` runs `flutter analyze` **and** `dart analyze` (riverpod_lint only reports in the latter, ADR-FND-02) |
| `test` | `test.sh` | unit + widget tests, lcov uploaded; gate ≥ 80% lines over `lib/core/**` and `lib/**/domain/**` (`check_coverage.py`) |
| `task-gate` | `pytest tools/ci/tests`, `tasks.py verify --all-done --run` | independent-verification gate: every `done` task keeps tagged tests, report, PASS rows |
| `android` | `build_android.sh` | debug dev-flavor APK, uploaded as `android-dev-debug-apk`. FND-06 adds `libvv_native.so` and the 16 KB-page check |
| `ios` | `build_ios.sh` | unsigned dev-flavor build, uploaded as `ios-dev-unsigned-app`. FND-06 adds `vv_native.xcframework` |
| `native-host` | `run_slot.sh native_host.sh FND-06` | **slot**: warns "did NOT run" until FND-06 delivers `tools/ci/native_host.sh` |

Slots (`run_slot.sh`) run `tools/ci/<script>` if present, otherwise emit a visible warning and pass.
Delivering the script is what activates the check — no workflow change needed.

Pinned: Flutter via `.fvmrc` (FVM 4.3.1 in `setup.sh`), Temurin JDK 17, action versions by tag.
Still to pin when FND-06 lands: NDK, CMake. Xcode is the macOS runner default.

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
