# FND-01 — Initialize Flutter Repository & Code Standards

**Workstream:** Foundation | **Phase:** 1 (Weeks 1–3) | **Size:** S | **Depends on:** — | **Source:** §5 Phase 1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
Create the Flutter monorepo with strict, enforced code style so every later task lands on a consistent base.

## Scope
- [x] Run `tools/setup/doctor.sh core` first; if it fails, stop and report the missing tools to the user (do not install system tools without approval).
- [x] Create Flutter app (iOS + Android only; disable web/desktop targets). Pin Flutter/Dart SDK via FVM (`.fvmrc`).
- [x] Set min OS targets: iOS 16+, Android API 26+ (arm64-v8a only for v1). Document rationale (NPU/Metal/Vulkan availability).
- [x] Add `very_good_analysis` (or equivalent strict lints), `dart format` line length, and custom rules (no `print`, no `dynamic`).
- [x] Feature-first folder layout: `lib/features/<feature>/{data,domain,presentation}`, `lib/core/`, `native/` for C/C++.
- [x] Build flavors: `dev`, `prod` (separate bundle IDs / app IDs, app icons).
- [x] Pre-commit hooks (format + analyze), `CONTRIBUTING.md`, `.editorconfig`.
- [x] Choose final app identifier name placeholder (`VaultVoice`) behind a single constant so a rename is cheap.

## Acceptance Criteria
- `flutter analyze` reports zero issues; `dart format --set-exit-if-changed .` passes.
- `fvm flutter run --flavor dev -t lib/main_dev.dart` launches the app on an iOS simulator and an Android emulator (physical-device runs happen in GATE-01).
- Folder layout and conventions documented in `CONTRIBUTING.md`.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-01-flutter-repo-init · **Date:** 2026-10-12
- **Summary:** Flutter app in `app/` (package `vaultvoice`, org `com.vaultvoice` placeholder), SDK pinned
  to Flutter 3.47.7 via `.fvmrc`. `very_good_analysis` 11 + `avoid_print`/`avoid_dynamic_calls` as errors
  and strict-casts/inference/raw-types. Feature-first layout under `lib/features`, `lib/core/app_info.dart`
  (`kAppName`), `main_dev.dart`/`main_prod.dart` → `bootstrap(Flavor)`. Android: `minSdk 26`, arm64-v8a only,
  `dev`/`prod` flavors (`.dev` suffix, per-flavor name + icons). iOS: deployment target 16.0, build configs
  `Debug|Release|Profile-{dev,prod}`, schemes `dev`/`prod`, per-flavor bundle ID, display name and AppIcon.
  `.editorconfig`, `lefthook.yml`, `CONTRIBUTING.md` (layout, flavors, min-OS rationale).
  Not verified on this machine (no Xcode / Android SDK): native compilation of the flavors and AC2.
  The committed iOS project has no `DEVELOPMENT_TEAM` (local signing is chosen per developer).
  `riverpod_lint` is deferred to FND-02 (needs Riverpod). No Podfile yet (no CocoaPods plugins; add with
  the first pod-based plugin, `platform :ios, '16.0'`). Splash screens are not flavor-specific yet.
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-01/AC1]
  - AC2: ⏳ device: docs/test-plans/device/FND-01.md
  - AC3: ✅ test: [FND-01/AC3]; artifact: CONTRIBUTING.md
- **Decisions:** none (SDK/lint choices follow the vv-flutter-architecture skill)
- **Follow-ups:** none

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-13 · **Commit:** 7b969547f514631d2787bc2b8793805ae017b5d8
- **Verdict:** FAIL
- **Gates:** format ✅ (0 files changed) · analyze ✅ (flutter analyze and dart analyze, no issues) · tests ✅ (repo standards 3 passed; full `fvm flutter test` 21 passed on the stacked FND-06 tree which contains this commit) · native smoke n/a · egress ✅ on the stacked tree · recording policy n/a (slot only) · CI run: local, fresh worktree
- **Acceptance criteria:**
  - AC1: ❌ `[FND-01/AC1]` only checks that `analysis_options.yaml` contains lint names. Adding `print('leak')` in `app/lib/core/app_info.dart` left that test green. Format and analyze are clean on this commit when run by hand, so the tree is fine today and the tagged test does not protect the criterion.
  - AC2: ❌ device checklist steps do not match the criterion. `docs/test-plans/device/FND-01.md` asks for a physical iPhone and a physical Android phone. The criterion is an iOS simulator and an Android emulator; physical runs are GATE-01. Result cells are blank. This machine has no Xcode and no Android SDK, so the launch was not re-run.
  - AC3: ✅ `[FND-01/AC3]` asserts `CONTRIBUTING.md` contains the layout, flavor, and min-OS headings. Passed.
- **Adversarial checks:** inserted `print('leak')` into `app_info.dart`; `[FND-01/AC1]` still passed. Restored the file. Did not launch the app (no simulator or emulator toolchain).
- **Skill/rule compliance:** feature-first layout, flavors, FVM pin, and the name constant match `vv-flutter-architecture`. No network or recording code in this task.
- **Issues found:**
  1. `[FND-01/AC1]` does not fail when analyze would fail. It must assert a clean `flutter analyze` and `dart format --set-exit-if-changed`, or the evidence must be something that actually runs those commands and fails closed.
  2. Rewrite `docs/test-plans/device/FND-01.md` so `[FND-01/AC2]` is `fvm flutter run --flavor dev -t lib/main_dev.dart` on an iOS simulator and an Android emulator, with the expected "dev flavor" launch. Leave Result blank until that run happens.

## Rework
- **Agent:** Claude Code · **Branch:** task/FND-01-rework · **Date:** 2026-10-13 — answers the Cursor FAIL report above (report left unchanged).
- **Issue 1 (`[FND-01/AC1]` could not fail):** AC1 evidence is now mainly the new pytest `tools/ci/tests/test_repo_standards.py`
  (`test_FND_01_AC1_format_gate_…`, `test_FND_01_AC1_analyze_gate_…`). It mirrors the working tree of `app/`,
  `packages/vv_native/`, `.fvmrc` and the CI scripts into a temp dir, runs the real `tools/ci/format.sh`
  (`dart format --set-exit-if-changed`) and `tools/ci/analyze.sh` (`flutter analyze` + `dart analyze --fatal-infos`)
  and asserts exit 0; then writes temp fixtures into the mirror only — an unformatted file (format gate must exit ≠ 0
  and name the file) and `print('x')` in `lib/` (analyze gate must exit ≠ 0 with `avoid_print`). The repository
  is never modified. Without fvm/flutter on PATH the test fails (no silent skip). It runs in CI `task-gate`
  (`pytest tools/ci/tests`) and through `tasks.py verify --run`.
  Mutation check (2026-10-13): appended `print('leak')` to `app/lib/core/app_info.dart` →
  `pytest tools/ci/tests/test_repo_standards.py -k analyze` → `1 failed` (`avoid_print • lib/core/app_info.dart:5:3`);
  restored → `2 passed in 152s`.
- **Issue 2 (device rows named physical phones):** `docs/test-plans/device/FND-01.md` rewritten: both `[FND-01/AC2]`
  rows are `fvm flutter run --flavor dev -t lib/main_dev.dart` on an arm64 iOS simulator and an arm64-v8a Android
  emulator (API 26+), expected "VaultVoice Dev" launch with the dev-flavor DEBUG banner; Result/Date/Tester blank.
  Physical devices stay in GATE-01.
- **Also fixed:** iOS `APP_DISPLAY_NAME` was "Vaultvoice Dev"/"Vaultvoice" (lower-case v) while Android and
  `kAppName` use "VaultVoice"; now "VaultVoice Dev"/"VaultVoice".
- **Still needed:** a run of both AC2 rows on a Mac with Xcode + Android SDK (not available on the authoring machine).


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ Host format and analyzer clean; read Dart lint/config checks and pytest mirror tests, which execute real format/analyze gates and inject unformatted/print fixtures. Rework fixes the earlier hollow-test finding.
  - AC2: ❌ Both simulator/emulator rows are correctly specified but Result/OS/Date/Tester are blank. Neither launch was run here (no Xcode, CocoaPods, Android SDK/JDK/emulators). Green unsigned/APK builds do not prove launch.
  - AC3: ✅ CONTRIBUTING.md documents feature layout, flavors, targets, hooks and the name constant; tagged document assertions passed.
- **Adversarial checks:** Disabled avoid_print enforcement locally; the [FND-01/AC1] tagged lint-configuration test failed, then passed after git checkout restored app/analysis_options.yaml. The shared pytest mirror separately proves real analyzer and formatter reject violations. Simulator/emulator execution is unavailable.
- **Skill/rule compliance:** FVM pin, strict analysis, iOS/Android flavors and arm64 targets inspected. The user exception permits pending physical-device runs; AC2 specifically requires simulator/emulator launches, so this report does not waive it. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** 
  1. AC2 lacks the required successful dev-flavor launch on an arm64 iOS simulator and arm64-v8a Android emulator. Run and date both rows in docs/test-plans/device/FND-01.md; this is an evidence gap, not a demonstrated launch defect.
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-01 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/FND-01-verify.log`.
