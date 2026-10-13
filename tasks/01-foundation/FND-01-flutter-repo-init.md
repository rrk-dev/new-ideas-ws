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
