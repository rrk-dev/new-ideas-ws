# FND-09 — macOS Desktop Target

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01, FND-02 | **Source:** User decision 2026-10-14 (desktop app; master plan was iOS & Android only)
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
VaultVoice launches as an arm64 macOS desktop app, dev and prod, on the same Record screen as iOS. Web, Linux, and Windows stay disabled.

## Scope
- [ ] Add the Flutter macOS runner under `app/macos`. Minimum macOS 13, arm64 only. Do not enable web, Linux, or Windows.
- [ ] `dev` and `prod` flavors match the existing iOS pattern: bundle id `com.vaultvoice.vaultvoice.dev` / `com.vaultvoice.vaultvoice`, display name "VaultVoice Dev" / "VaultVoice".
- [ ] `fvm flutter run -d macos --flavor dev -t lib/main_dev.dart` opens a window on the Record screen with the debug banner and the dev-only CallGuard debug action.
- [ ] Window can be used with a pointer: minimum content size, close/minimize/zoom. No new product features.
- [ ] Document the macOS target and the user decision in `CONTRIBUTING.md`. Update the platforms line in `AGENTS.md` to include macOS 13+ arm64.
- [ ] Leave iOS and Android projects building as they do today.

## Acceptance Criteria
- `fvm flutter build macos --flavor dev -t lib/main_dev.dart` produces an arm64 dev app.
- A macOS launch reaches the Record screen (device row in `docs/test-plans/device/FND-09.md`).
- `CONTRIBUTING.md` states macOS 13+ arm64, and that web, Linux, and Windows are out of scope.

## Notes
FND-01 deliberately disabled desktop targets. This task is the exception the user asked for. Do not record phone or system audio. Do not add analytics.
