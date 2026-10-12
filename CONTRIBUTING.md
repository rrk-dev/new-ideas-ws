# Contributing to VaultVoice

Agent-facing rules live in [`AGENTS.md`](AGENTS.md); this file covers the developer setup and
conventions for the Flutter app in `app/`.

## Setup
```bash
brew tap leoafarias/fvm && brew install fvm lefthook
fvm install                      # installs the SDK pinned in .fvmrc (repo root)
(cd app && fvm flutter pub get)
lefthook install                 # pre-commit: format + analyze + task lint
```
Always run Flutter through FVM (`fvm flutter …`, `fvm dart …`). `tools/setup/doctor.sh` checks
the toolchain.

## Quality gates (run from `app/`)
```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze          # zero issues
fvm flutter test
```
Also from the repo root: `python3 .agents/skills/vv-task-workflow/scripts/tasks.py validate`.

## Running the app
Flavors are mandatory; there is no un-flavored build.
```bash
cd app
fvm flutter run --flavor dev  -t lib/main_dev.dart     # com.vaultvoice.vaultvoice.dev
fvm flutter run --flavor prod -t lib/main_prod.dart    # com.vaultvoice.vaultvoice
```
| Flavor | Android applicationId | iOS bundle ID | Display name | Icon |
|---|---|---|---|---|
| `dev` | `com.vaultvoice.vaultvoice.dev` | `com.vaultvoice.vaultvoice.dev` | VaultVoice Dev | orange (placeholder) |
| `prod` | `com.vaultvoice.vaultvoice` | `com.vaultvoice.vaultvoice` | VaultVoice | indigo (placeholder) |

iOS build configurations are `Debug|Release|Profile-<flavor>`, with schemes `dev` and `prod`.
Signing: the committed project has no `DEVELOPMENT_TEAM`; select your team in Xcode (Runner →
Signing & Capabilities) for device builds. The bundle ID prefix `com.vaultvoice` is a placeholder
until the product name/identifier is decided.

Regenerate icons after replacing `app/assets/icon/icon_{dev,prod}.png`:
```bash
cd app
fvm dart run flutter_launcher_icons -f flutter_launcher_icons-dev.yaml
fvm dart run flutter_launcher_icons -f flutter_launcher_icons-prod.yaml
```

## Platform targets and rationale
- **iOS 16.0+** and **Android API 26+ (Android 8.0), arm64-v8a only** for v1.
- Why: on-device Whisper/LLM inference relies on Metal 3-era GPUs (iOS 16 baseline: A12+ devices)
  and Vulkan 1.1 / modern audio and background-execution APIs on Android 8+. Restricting to arm64
  drops 32-bit ARM and x86 NEON/SIMD code paths, halves native binary size and keeps whisper.cpp /
  llama.cpp builds to one ABI. Devices that cannot run the models adequately are out of scope.
- Enforced in `ios/Runner.xcodeproj` (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`) and
  `android/app/build.gradle.kts` (`minSdk = 26`, `abiFilters += arm64-v8a`).
- An arm64 Android *emulator* image is required (x86_64 images will not install the app).

## Code standards
- Lints: `very_good_analysis` plus `avoid_print` and `avoid_dynamic_calls` as errors, strict
  casts/inference/raw types. No `print` (use the logger from FND-07), no `dynamic` in public APIs.
- Formatting: `dart format` defaults (80 columns); `.editorconfig` (LF, UTF-8, 2 spaces).
- The product name lives only in `lib/core/app_info.dart` (`kAppName`); do not hard-code it.
  Native display names are set per flavor (`app_name` resValue / `APP_DISPLAY_NAME`).

## Folder layout
```
app/
  lib/
    main_dev.dart  main_prod.dart  bootstrap.dart  app.dart
    core/                  cross-cutting: errors, logging, network gateway, platform interfaces
    features/<feature>/
      domain/              entities, repository interfaces, pure services (no Flutter/drift/FFI)
      data/                repository impls, DAOs, platform/FFI adapters
      presentation/        screens, widgets, Riverpod notifiers
  test/unit  test/widget  test/golden  test/fakes  integration_test/
native/                    C/C++ (whisper.cpp, llama.cpp, bridge) — added by FND-06
```
Each feature lives in `lib/features/<feature>/`: `recording`, `transcription`, `extraction`, `profiles`, `templates`, `export`,
`library`, `models`, `licensing`, `settings`, `onboarding`, `pipeline`.
Dependency direction: `presentation → domain ← data`.

## Git
- Branch `task/<TASK-ID>-<slug>`; Conventional Commits with the task ID
  (`feat(FND-04): add drift schema v1`); PR title `[<TASK-ID>] <task title>`.
- Never commit models (`*.gguf`, `ggml-*.bin`) or real recordings.
