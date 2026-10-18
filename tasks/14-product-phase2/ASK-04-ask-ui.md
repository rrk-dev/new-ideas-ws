# ASK-04 — Ask-your-notes UI

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** ASK-03, UIX-01, APP-02, LIC-05 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes across the library)
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-licensing-iap, vv-privacy-security, vv-testing

## Goal
Users can ask a question across the whole library, or about one recording, and jump from each cited source straight to the transcript position.

## Scope
- [x] Entry points per the UIX-01 design: library-level Ask and a per-recording Ask in the recording detail.
- [x] Question input, in-progress state with cancel, answer with tappable citations (open the recording at the timestamp via the existing `TranscriptNavigator`), and a clear "not found in your notes" state.
- [x] Unavailable states: 3B model not installed (offer download via the Models screen with the size shown), device tier too low, feature locked (`FeatureGate`, per LIC-05), no recordings yet, transcription currently running (per ADR-ASK-02).
- [x] Chat history screen only if ASK-02 chose to persist history; delete-one and delete-all controls; honours app lock.
- [x] Accessibility and l10n (English strings in ARB; semantics labels; large text) per APP-06; uses the Lumen design system (APP-08 tokens/widgets).

## Acceptance Criteria
- Widget tests with the fake `AskEngine` cover answer, not-found, cancel, error, model-missing, tier-too-low and locked states (`[ASK-04/AC1]`).
- Tapping a citation opens the recording at that timestamp (widget/integration test `[ASK-04/AC2]`).
- `accessibility_test` contrast/tap-target checks pass for the new screens in light and dark, and `hardcoded_strings_test` passes (`[ASK-04/AC3]`).
- On a physical device with the 3B model, a real question over a seeded library returns a cited answer (device row `docs/test-plans/device/ASK-04.md`, ⏳ until run).
- Airplane-mode run: asking works with the network off (device row).

## Notes
- ADR-ASK-02 (Proposed): the 1B is not used for Ask. High tier without the 3B shows "Ask requires the 3B model" (size + Models screen link); Mid/Low show "Ask isn't available on this device". Ask is Free (no `FeatureGate`) pending the product questions in the ADR; history is optional with a "Save Ask history" setting.

## Open Decisions
- PRODUCT-DECISION (human, 2026-10-18): the whole Ask entry (library button, recording hub tab, history link) is behind the setting `ask.enabled`, **off by default**, until the answer-quality decision: ASK-03's 90 % gates are not met on the 3B (see ASK-05). Flip the default in `AppSettings.askEnabled` when the user decides.
- PRODUCT-DECISION (human, 2026-10-17): no Pro tier is enforced (`kProTierEnforced = false`), so Ask is Free and `ensureFeature(Feature.askNotes)` unlocks everywhere; the locked state exists for when LIC-05 enforcement is switched on.
- PRODUCT-DECISION (human, 2026-10-17): Mid and Low tier devices show "Ask isn't available on this device"; High tier without the 3B shows "Ask requires the 3B model" with a download action. The 1B is never used for Ask.
- PRODUCT-DECISION (human, 2026-10-17): chat history is saved by default (`ask.save_history`), expires after 30 days, and has per-chat delete and clear-all.
- Because answers can be wrong, every answer shows "Answers can be wrong — check the sources." and its source chips; refusals read "I couldn't find that in your notes."
- Not in scope, left as follow-up: a "no transcript yet" empty state for a single recording (the retriever simply finds nothing and the refusal text shows).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/ASK-04-ask-ui · **Date:** 2026-10-18
- **Summary:** Ask UI over the ASK-03 engine: `AskPanel` (library screen and recording hub tab), chat controller, answer card with tappable citation chips, history screen, Settings tiles (`ask.enabled` off by default, `ask.save_history` on), routes `/library/ask` and `/library/ask/history`, providers wiring a 3B-only `AskLlmEngine` with its own `ModelResidency`, availability states, pipeline-busy note and retrieval-only fallback when memory is short, app lock clears the in-memory chat and cancels a running question. No question or answer text is logged. No new dependency, host or network path.
- **Acceptance evidence:**
  - AC1: ✅ test: [ASK-04/AC1]
  - AC2: ✅ test: [ASK-04/AC2]
  - AC3: ✅ test: [ASK-04/AC3]
  - AC4: ⏳ device: docs/test-plans/device/ASK-04.md
  - AC5: ⏳ device: docs/test-plans/device/ASK-04.md
