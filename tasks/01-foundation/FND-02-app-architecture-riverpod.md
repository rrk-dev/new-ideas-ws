# FND-02 — App Architecture Skeleton (Riverpod, Routing, Error Handling)

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** §4.1
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing, vv-decision-records

## Goal
Establish the layered architecture and state-management conventions all features will follow.

## Scope
- [x] Add Riverpod (with `riverpod_generator` + `riverpod_lint`); define provider conventions (repositories, services, notifiers).
- [x] Routing via `go_router` with typed routes; shell for Record / Library / Profiles / Settings tabs.
- [x] Domain error model (`Result`/sealed failures) and a global error boundary that never crashes the recording.
- [x] Theming (light/dark), design tokens, base widgets.
- [x] Platform-channel/FFI abstraction interfaces (`SttEngine`, `LlmEngine`, `AudioRecorder`, `VaultWriter`) with fake implementations for tests.
- [x] Minimal `NetworkGateway` (`lib/core/network/`) with config allowlist — the only HTTP client; MDL-01/02 use it, SEC-02 hardens/audits it.
- [x] Dependency overrides for tests (ProviderContainer helpers).

## Acceptance Criteria
- App boots into tab shell with placeholder screens.
- Each engine interface has a fake implementation and a passing unit test using provider overrides.
- Architecture decision record (ADR-FND-02) committed under `docs/adr/`.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-02-app-architecture-skeleton (stacked on task/FND-01-flutter-repo-init) · **Date:** 2026-10-12
- **Summary:** Riverpod (code-gen) + `riverpod_lint` plugin, typed go_router tab shell (Record/Library/Profiles/Settings
  placeholders), `Failure`/`Result<T>` + error boundary, Material 3 light/dark theme + tokens + `PlaceholderScreen`,
  engine interfaces (`AudioRecorder`, `SttEngine`, `LlmEngine`, `VaultWriter`, `Clock`) with fakes in `test/fakes/`,
  `NetworkGateway` (https + allowlist + offline, no redirects), `test/helpers/test_container.dart`. ADR-FND-02.
  Stacked on FND-01, which is still in review (device runs pending). `riverpod_lint` is only reported by
  `dart analyze`, not `flutter analyze` (documented; FND-03 must run both).
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-02/AC1]
  - AC2: ✅ test: [FND-02/AC2]
  - AC3: ✅ artifact: docs/adr/ADR-FND-02-app-architecture.md; test: [FND-02/AC3]
- **Decisions:** ADR-FND-02-app-architecture
- **Follow-ups:** FND-03 to run `fvm dart analyze` in CI; l10n/ARB for tab labels; other engine interfaces by owning tasks
