# FND-02 — App Architecture Skeleton (Riverpod, Routing, Error Handling)

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** §4.1
**Status:** done
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


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ app_shell_test.dart checks NavigationBar, all four labels, initial RecordScreen and navigation to each tab. Current screens have grown beyond placeholders.
  - AC2: ✅ engines_test.dart exercises provider overrides for STT, LLM, CaptureBackend (the evolved recording abstraction) and VaultWriter, including results, progress/tokens, cancellation and injected errors. core_test.dart checks Result behavior, HTTPS/allowlist/offline denials.
  - AC3: ✅ Read docs/adr/ADR-FND-02-app-architecture.md and current typed routes/providers; artifact exists. The AC3-tagged error-boundary test checks handled errors and type-only reporting, while the ADR itself supplies the document criterion.
- **Adversarial checks:** Changed initialLocation from RecordRoute to LibraryRoute; [FND-02/AC1] boot test failed and passed after git checkout restored app_router.dart. Reviewed pre-cancelled requests, injected failures, missing default engines, offline/empty allowlist and non-HTTPS/foreign-host rejection.
- **Skill/rule compliance:** Code-generated Riverpod, typed go_router shell, domain engine seams and Result/Failure follow the listed architecture/testing/ADR skills. Later recording integration replaces the original recorder seam with CaptureBackend; its fake is tested. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** none
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-02 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/FND-02-verify.log`.
- **Pending for done:** dependency FND-01 is not done.
