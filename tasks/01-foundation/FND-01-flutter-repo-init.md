# FND-01 — Initialize Flutter Repository & Code Standards

**Workstream:** Foundation | **Phase:** 1 (Weeks 1–3) | **Size:** S | **Depends on:** — | **Source:** §5 Phase 1
**Status:** review
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
