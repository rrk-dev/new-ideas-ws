# ASK-04 — Ask-your-notes UI

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** ASK-03, UIX-01, APP-02, LIC-05 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes across the library)
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-licensing-iap, vv-privacy-security, vv-testing

## Goal
Users can ask a question across the whole library, or about one recording, and jump from each cited source straight to the transcript position.

## Scope
- [ ] Entry points per the UIX-01 design: library-level Ask and a per-recording Ask in the recording detail.
- [ ] Question input, in-progress state with cancel, answer with tappable citations (open the recording at the timestamp via the existing `TranscriptNavigator`), and a clear "not found in your notes" state.
- [ ] Unavailable states: 3B model not installed (offer download via the Models screen with the size shown), device tier too low, feature locked (`FeatureGate`, per LIC-05), no recordings yet, transcription currently running (per ADR-ASK-02).
- [ ] Chat history screen only if ASK-02 chose to persist history; delete-one and delete-all controls; honours app lock.
- [ ] Accessibility and l10n (English strings in ARB; semantics labels; large text) per APP-06; uses the Lumen design system (APP-08 tokens/widgets).

## Acceptance Criteria
- Widget tests with the fake `AskEngine` cover answer, not-found, cancel, error, model-missing, tier-too-low and locked states (`[ASK-04/AC1]`).
- Tapping a citation opens the recording at that timestamp (widget/integration test `[ASK-04/AC2]`).
- `accessibility_test` contrast/tap-target checks pass for the new screens in light and dark, and `hardcoded_strings_test` passes (`[ASK-04/AC3]`).
- On a physical device with the 3B model, a real question over a seeded library returns a cited answer (device row `docs/test-plans/device/ASK-04.md`, ⏳ until run).
- Airplane-mode run: asking works with the network off (device row).
