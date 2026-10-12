# FND-01 — Initialize Flutter Repository & Code Standards

**Workstream:** Foundation | **Phase:** 1 (Weeks 1–3) | **Size:** S | **Depends on:** — | **Source:** §5 Phase 1
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
Create the Flutter monorepo with strict, enforced code style so every later task lands on a consistent base.

## Scope
- [ ] Run `tools/setup/doctor.sh core` first; if it fails, stop and report the missing tools to the user (do not install system tools without approval).
- [ ] Create Flutter app (iOS + Android only; disable web/desktop targets). Pin Flutter/Dart SDK via FVM (`.fvmrc`).
- [ ] Set min OS targets: iOS 16+, Android API 26+ (arm64-v8a only for v1). Document rationale (NPU/Metal/Vulkan availability).
- [ ] Add `very_good_analysis` (or equivalent strict lints), `dart format` line length, and custom rules (no `print`, no `dynamic`).
- [ ] Feature-first folder layout: `lib/features/<feature>/{data,domain,presentation}`, `lib/core/`, `native/` for C/C++.
- [ ] Build flavors: `dev`, `prod` (separate bundle IDs / app IDs, app icons).
- [ ] Pre-commit hooks (format + analyze), `CONTRIBUTING.md`, `.editorconfig`.
- [ ] Choose final app identifier name placeholder (`VaultVoice`) behind a single constant so a rename is cheap.

## Acceptance Criteria
- `flutter analyze` reports zero issues; `dart format --set-exit-if-changed .` passes.
- `fvm flutter run --flavor dev -t lib/main_dev.dart` launches the app on an iOS simulator and an Android emulator (physical-device runs happen in GATE-01).
- Folder layout and conventions documented in `CONTRIBUTING.md`.
