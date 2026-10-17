# LIC-05 — Free / Pro / Enterprise placement for the Phase 2 features

**Workstream:** Licensing | **Phase:** 5 | **Size:** S | **Depends on:** LIC-01, LIC-02, ASK-01, TPL-04, MAP-01, TSK-01, QCP-01 | **Source:** User decision 2026-10-16 (product Phase 2); product decision required
**Status:** todo
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-testing

## Goal
Every new Phase 2 capability has an explicit, tested tier placement in the single feature matrix, chosen by the product owner.

## Scope
- [ ] Ask the user (do not assume) for each feature: quick capture, Lecture / Sales conversation / Interview profiles, ask-your-notes, mind maps, Reminders export, Notes export. User direction 2026-10-17: all Free; the open conflict is the 3B model (Pro under the size rule), so ask whether it gets an exception. Present the facts that constrain the choice: the 3B model is already `Feature.largeLlm` (Pro) under the existing size rule, built-in profiles carry a `tier` field (meeting is free; warranty and engineering are pro).
- [ ] Add `Feature` values and `kFeatureMatrix` rows for the chosen features (free / pro / enterprise / personal columns) with a unit test for every cell; no feature check outside `EntitlementService`/`FeatureGate`.
- [ ] Set the `tier` of each new built-in profile to the decided value and remove the provisional `PRODUCT-DECISION` markers left by TPL-01/02/03.
- [ ] Update the paywall copy and product docs (`docs/iap-products.md`) only where the decision changes what Pro lists; no store product ids or prices change in this task.
- [ ] Record the decision and its date in the Open Decisions table of `tasks/README.md`.

## Acceptance Criteria
- Each Phase 2 feature has a row in `kFeatureMatrix` and a passing cell test (`[LIC-05/AC1]`).
- The decision is recorded, with the date and who decided, in `tasks/README.md` Open Decisions (artifact).
- Gated entry points (Ask, mind map generation, task export, new profiles) show the paywall for ineligible tiers and work for eligible ones in widget tests (`[LIC-05/AC3]`).
- Personal builds still unlock everything except organisation management (existing behaviour test stays green).
- `docs/iap-products.md` and paywall strings match the matrix (test or checklist row).
