---
name: vv-flutter-architecture
description: "Flutter app structure for VaultVoice: FVM, flavors, lints, feature-first layout, Riverpod code-gen, go_router, Result/Failure errors, engine interfaces with fakes, Pigeon channels, theming, l10n, accessibility. Use for any Dart UI or app-layer code."
---

# Flutter App Architecture & Conventions

## Project setup (FND-01)
- Flutter app lives in `app/` (package `vaultvoice`). Pin SDK with FVM at the **repo root**: `fvm use <exact stable
  version> --force --skip-pub-get` (`--force` skips the "not a Flutter project" check at root) writes `.fvmrc` (commit it; gitignore `.fvm/`); FVM resolves it from
  sub-directories, so `app/` and `packages/` share one SDK. Always run `fvm flutter …`.
- Create with `fvm flutter create --org <reverse-domain> --platforms ios,android --project-name vaultvoice app`.
- Min targets: iOS 16.0 (`ios/Podfile` `platform :ios, '16.0'` + Xcode deployment target),
  Android `minSdk 26`, `ndk { abiFilters 'arm64-v8a' }`.
- Flavors `dev` and `prod`: Android `productFlavors` (applicationIdSuffix `.dev`), iOS schemes +
  xcconfigs; entrypoints `lib/main_dev.dart`, `lib/main_prod.dart` calling `bootstrap(Flavor)`.
- Lints: `very_good_analysis` (already enables `avoid_print` and strict casts/inference/raw types)
  + `riverpod_lint` 3.x as an **analysis_server_plugin** — in `analysis_options.yaml`: a top-level
  `plugins:` map with `riverpod_lint: <pinned version>`. No `custom_lint` dependency; diagnostics show in
  `flutter analyze`. Verify against the riverpod_lint README for the pinned version.
- Product name in one place: `lib/core/app_info.dart` (`const kAppName = 'VaultVoice';`).
- Also enable `avoid_dynamic_calls` and forbid `dynamic` in public APIs (review rule); line length
  = `dart format` default (80) unless an ADR changes it; `.editorconfig` (LF, UTF-8, 2 spaces).
- Pre-commit: `lefthook` (`lefthook.yml` → `fvm dart format --set-exit-if-changed`, `fvm flutter
  analyze`, `tasks.py validate`); document `lefthook install` in `CONTRIBUTING.md`.
- Per-flavor icons/splash: `flutter_launcher_icons` + `flutter_native_splash` configs per flavor.
- Min-OS rationale (write in `CONTRIBUTING.md`): iOS 16 / Android 26 cover Metal 3-era GPUs,
  Vulkan 1.1 and the APIs our audio/background code uses; arm64 only (no 32-bit NEON paths).

## Layout
```
lib/
  main_dev.dart / main_prod.dart / bootstrap.dart / app.dart
  core/  errors/ logging/ network/ platform/ routing/ theme/ l10n/ utils/
  features/<feature>/
    domain/        entities (immutable, freezed), repository interfaces, pure services
    data/          repository impls, drift DAOs, platform/FFI adapters
    presentation/  screens, widgets, notifiers (Riverpod)
```
Features: `recording`, `transcription`, `extraction`, `profiles`, `templates`, `export`,
`library`, `models`, `licensing`, `settings`, `onboarding`, `pipeline`.
Dependency direction: presentation → domain ← data. `domain/` imports no Flutter, no drift, no FFI.

## Routing (FND-02)
`go_router` + `go_router_builder` typed routes (`@TypedGoRoute`, `@TypedStatefulShellRoute`);
tab shell = `StatefulShellRoute.indexedStack` with branches Record / Library / Profiles / Settings.
Deep links (notifications → recording detail) use the typed routes.

## Network gateway (FND-02, minimal — hardened in SEC-02)
`lib/core/network/network_gateway.dart`: the only HTTP client, constructed with an allowlist from
config (model catalog/CDN hosts). MDL-01/02 use it from day one; SEC-02 adds the CI egress guard
coverage, activity log and audit.

## Riverpod rules
- Code-gen only (`@riverpod` / `@Riverpod(keepAlive: true)`); run
  `fvm dart run build_runner build --delete-conflicting-outputs`. Commit generated `*.g.dart`
  and `*.freezed.dart` (so all three agents build without a codegen step mismatch).
- keepAlive for engines, repositories, DB, pipeline; autoDispose for screen state.
- Notifiers expose immutable state (freezed unions for loading/ready/error).
- No `ref.read` inside `build`; use `ref.watch`. Side effects only in notifier methods.
- Tests override providers via `ProviderContainer(overrides: [...])` / `ProviderScope`.

## Engine interfaces (FND-02) — in `lib/core/platform/`
`AudioRecorder`, `SttEngine`, `LlmEngine`, `VadEngine`, `DiarizationEngine`, `VaultWriter`,
`ModelStore`, `EntitlementService`, `DeviceCapabilities`, `Clock`.
Each has: abstract interface (domain types only), real impl in the owning feature's `data/`,
and a `Fake*` in `test/fakes/` (also used by integration tests that run without models).

## Error model
- `sealed class Failure` (e.g. `PermissionFailure`, `StorageFailure`, `ModelMissingFailure`,
  `OutOfMemoryFailure`, `CancelledFailure`, `NativeFailure(code, message)`).
- Repositories/engines return `Result<T, Failure>` (own small sealed type in `core/errors`) —
  never throw across layer boundaries. Map native error codes in one place.
- `bootstrap` installs `FlutterError.onError` + `PlatformDispatcher.instance.onError` that log
  locally (`vv-privacy-security` logging rules) — the recorder must survive UI errors.

## Platform channels
- Prefer **Pigeon** for typed host APIs (SAF, bookmarks, audio session, background tasks,
  StoreKit 2, device memory). One Pigeon file per concern in `app/pigeons/`.
- Native code: Kotlin in `android/app/src/main/kotlin/.../`, Swift in `ios/Runner/`.
- FFI (whisper/llama) is NOT a platform channel — see `vv-ffi-bridge`.

## UI conventions
- Material 3, light/dark, tokens in `core/theme`. No hard-coded colors/strings in widgets.
- All user-facing strings in ARB (`lib/core/l10n/arb/app_en.arb`), `flutter gen-l10n`.
- Every interactive widget has a `Semantics` label; record button announces state.
- Long lists use `ListView.builder`; heavy work never in `build`.
- Screens must handle: loading, empty, error (with retry), permission-denied states.
- Accessibility tests: `expect(tester, meetsGuideline(textContrastGuideline))`,
  `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` on every
  screen; hard-coded strings caught by a test that scans `lib/**/presentation/**` for string
  literals inside `Text(` (allowlist for keys/symbols).
- Local notifications: `flutter_local_notifications` (verify maintenance) with payload = typed
  route; Android channel "Processing" (low importance) and "Recording" (ongoing).
- Home-screen widget / quick-settings tile / Live Activity (nice-to-haves): native extensions
  (WidgetKit + ActivityKit on iOS, `TileService` + App Widget on Android) that only open the
  recording screen or show state; `home_widget` package can bridge state. Recording rules:
  `vv-audio-capture` policy.

## Verification
- `fvm dart format --set-exit-if-changed .` · `fvm flutter analyze` (0 issues) · `fvm flutter test`.
- New screen ⇒ widget tests for each state; key screens ⇒ golden tests (`vv-testing`).
