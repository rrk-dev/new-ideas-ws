# ADR-FND-02 — App architecture: Riverpod, go_router, Result/Failure, engine interfaces

- **Status:** Accepted
- **Date:** 2026-10-12
- **Task:** FND-02
- **Deciders:** Claude Code (implementer); pending independent verifier
- **Supersedes:** —

## Context
All feature groups build on one skeleton: state management, routing, error handling, the engine
seams (STT, LLM, recorder, vault) and the single network client. Constraints: offline/private (no
content in errors/logs, one network gateway), arm64 mobile, three agents working in parallel
(generated code must be committed, interfaces stable), testable without models or devices.

## Options
1. **Riverpod (code-gen) + go_router typed routes + sealed `Result<T>`** — recommended in
   `vv-flutter-architecture`.
2. **Bloc + auto_route** — more ceremony; no compile-time provider overrides for fakes.
3. **Provider/GetIt + manual routes** — weaker testability and no typed routes.

## Decision
Option 1:
- **State/DI:** `flutter_riverpod` 3.4 + `riverpod_annotation`/`riverpod_generator` (`@Riverpod`,
  `Ref`), `riverpod_lint` 3.1.9 as an analyzer plugin. Engines are `keepAlive` providers with *no*
  default: real implementations are injected through `bootstrap(overrides: …)` by the owning feature;
  tests override with `test/fakes/*` via `fakeEngineOverrides()`.
- **Routing:** `go_router` 18 + `go_router_builder` typed routes; `StatefulShellRoute` with branches
  Record / Library / Profiles / Settings (`core/routing`).
- **Errors:** `sealed class Failure` (content-free messages) and `sealed class Result<T>`
  (`Ok`/`Err`, failure type fixed to `Failure` — one type parameter instead of two). Global error
  boundary (`installErrorBoundary`) absorbs `FlutterError`/`PlatformDispatcher` errors and reports
  only the error's runtime type.
- **Engine interfaces** in `core/platform`: `AudioRecorder`, `SttEngine`, `LlmEngine`, `VaultWriter`,
  `Clock`; cooperative `CancelToken` + `ProgressCallback`. Fakes support progress, cancellation,
  `failWith`, and timing.
- **Network:** `NetworkGateway` in `core/network` — https only, exact-host allowlist, offline switch,
  redirects not followed (a 3xx could leave the allowlist). SEC-02 hardens it.
- **No `freezed`** for now: plain `final class`/sealed types suffice; add it when a feature needs
  copyWith/unions on state.
- Generated `*.g.dart` are committed.

## Consequences
- Positive: engines swap between fake and real per environment; failures are exhaustively switchable.
- Negative / risks:
  - `flutter analyze` (3.47) does **not** print `riverpod_lint` diagnostics; `dart analyze` does.
    Gates and hooks therefore run both (FND-03 must do the same).
  - Interface shapes (`SttEngine.transcribe` etc.) are first drafts; owning tasks (STT-xx, LLM-xx,
    AUD-xx, EXP-xx) may extend them additively — breaking changes need a note here.
- Follow-up tasks: remaining interfaces from the skill (`VadEngine`, `DiarizationEngine`, `ModelStore`,
  `EntitlementService`, `DeviceCapabilities`) are defined by their owning tasks; l10n/ARB wiring
  (tab labels are literals for now).
