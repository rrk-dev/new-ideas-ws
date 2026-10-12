# FND-02 — App Architecture Skeleton (Riverpod, Routing, Error Handling)

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** §4.1
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing, vv-decision-records

## Goal
Establish the layered architecture and state-management conventions all features will follow.

## Scope
- [ ] Add Riverpod (with `riverpod_generator` + `riverpod_lint`); define provider conventions (repositories, services, notifiers).
- [ ] Routing via `go_router` with typed routes; shell for Record / Library / Profiles / Settings tabs.
- [ ] Domain error model (`Result`/sealed failures) and a global error boundary that never crashes the recording.
- [ ] Theming (light/dark), design tokens, base widgets.
- [ ] Platform-channel/FFI abstraction interfaces (`SttEngine`, `LlmEngine`, `AudioRecorder`, `VaultWriter`) with fake implementations for tests.
- [ ] Minimal `NetworkGateway` (`lib/core/network/`) with config allowlist — the only HTTP client; MDL-01/02 use it, SEC-02 hardens/audits it.
- [ ] Dependency overrides for tests (ProviderContainer helpers).

## Acceptance Criteria
- App boots into tab shell with placeholder screens.
- Each engine interface has a fake implementation and a passing unit test using provider overrides.
- Architecture decision record (ADR-FND-02) committed under `docs/adr/`.
