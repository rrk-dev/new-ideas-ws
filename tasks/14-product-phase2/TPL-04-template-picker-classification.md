# TPL-04 — Template picker, auto-classification and eval for the new profiles

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** TPL-01, TPL-02, TPL-03, PRF-06, PRF-09, APP-05 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** todo
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-flutter-architecture, vv-benchmark-eval, vv-testing, vv-licensing-iap

## Goal
Users can choose Lecture, Sales conversation and Interview (or let Auto pick them) before or after recording, and the quality of Auto selection is measured across all six built-in profiles.

## Scope
- [ ] Profile choice UI lists all built-in profiles with name, one-line description and icon (uses the existing profile list/gating; no new gating logic — `FeatureGate`/`EntitlementService` only).
- [ ] Extend Auto classification (PRF-06) with the new profile ids, descriptions and `classify.keywords`; keep the low-confidence ask-the-user path.
- [ ] Mixed classification eval set (≥ 20 transcripts per profile, including ambiguous ones such as a meeting that mentions a sale, a lecture with Q&A) and a confusion matrix report in `tools/bench/eval/`.
- [ ] Re-run extraction on an existing recording with a different profile (existing PRF-06 behaviour) works for the new profiles, and the review-before-export screen (APP-05) renders their schemas through `SchemaForm`.
- [ ] Update `docs/profile-spec.md` and `docs/templates.md` listings of built-in profiles/templates and the in-app l10n strings (English only; `hardcoded_strings_test` stays green).

## Acceptance Criteria
- Auto selection accuracy ≥ 90% on the mixed eval set across the six built-in profiles (the PRF-06 bar), reported with the confusion matrix (artifact).
- Classification still adds < 10 s on a mid-tier device (device row, PRF-06 protocol).
- The picker shows locked/unlocked state per profile exactly as `kFeatureMatrix` says (widget test `[TPL-04/AC3]`).
- A recording can be re-extracted with each new profile and exported; review form renders every schema field type used (widget test `[TPL-04/AC4]`).
- Existing profile, classification and goldens tests stay green.
