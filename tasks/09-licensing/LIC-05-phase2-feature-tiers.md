# LIC-05 — Free / Pro / Enterprise placement for the Phase 2 features

**Workstream:** Licensing | **Phase:** 5 | **Size:** S | **Depends on:** LIC-01, LIC-02, ASK-01, TPL-04, MAP-01, TSK-01, QCP-01 | **Source:** User decision 2026-10-16 (product Phase 2); product decision required
**Status:** todo
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-testing

## Goal
Every new Phase 2 capability has an explicit, tested tier placement in the single feature matrix, chosen by the product owner. **Decision 2026-10-17: there is no Pro tier for now.** Every feature is available to everyone; Pro gating stays in the code but is suppressed, to be enabled later.

## Scope
- [ ] Record the decision (2026-10-17, product owner): Phase 2 features (quick capture, Lecture / Sales conversation / Interview profiles, ask-your-notes incl. the 3B model, mind maps, Reminders export) are all unlocked. The intended future tier of each stays in `kFeatureMatrix` (the 3B model remains `Feature.largeLlm` = Pro by the size rule) so enabling Pro later is a configuration change, not a rewrite.
- [ ] Add one switch (for example `proTierEnforced`, default `false`) in `EntitlementService` that, when off, treats Pro-gated features as unlocked for everyone, including existing Pro-gated items (warranty/engineering profiles, large LLM). No feature check outside `EntitlementService`/`FeatureGate`. Decide in this task whether the switch is a build/config constant or a runtime setting, and document how to turn it on.
- [ ] Add `Feature` values and `kFeatureMatrix` rows for the chosen features (free / pro / enterprise / personal columns) with a unit test for every cell; no feature check outside `EntitlementService`/`FeatureGate`.
- [ ] Set the `tier` of each new built-in profile to its intended future value (it has no effect while the switch is off) and remove the provisional `PRODUCT-DECISION` markers left by TPL-01/02/03.
- [ ] While the switch is off, paywall entry points are hidden or inert (no purchase prompts); store product ids and prices are untouched; note the suppression in `docs/iap-products.md`.
- [ ] Record the decision and its date in the Open Decisions table of `tasks/README.md`.

## Acceptance Criteria
- Each Phase 2 feature has a row in `kFeatureMatrix` and a passing cell test (`[LIC-05/AC1]`).
- The decision is recorded, with the date and who decided, in `tasks/README.md` Open Decisions (artifact).
- With the switch off, Ask, mind maps, Reminders export, the new profiles and the 3B model work on a Free entitlement, with no paywall shown (widget tests `[LIC-05/AC3]`).
- With the switch on, the same entry points show the paywall for ineligible tiers and work for eligible ones (widget tests `[LIC-05/AC6]`).
- Personal builds still unlock everything except organisation management (existing behaviour test stays green).
- `docs/iap-products.md` documents the switch and how to enable Pro later (checklist row).
