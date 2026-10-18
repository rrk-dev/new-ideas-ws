# LIC-05 — Free / Pro / Enterprise placement for the Phase 2 features

**Workstream:** Licensing | **Phase:** 5 | **Size:** S | **Depends on:** LIC-01, LIC-02, ASK-01, TPL-04, MAP-01, TSK-01, QCP-01 | **Source:** User decision 2026-10-16 (product Phase 2); product decision required
**Status:** review
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-testing

## Goal
Every new Phase 2 capability has an explicit, tested tier placement in the single feature matrix, chosen by the product owner. **Decision 2026-10-17: there is no Pro tier for now.** Every feature is available to everyone; Pro gating stays in the code but is suppressed, to be enabled later.

## Scope
- [x] Record the decision (2026-10-17, product owner): Phase 2 features (quick capture, Lecture / Sales conversation / Interview profiles, ask-your-notes incl. the 3B model, mind maps, Reminders export) are all unlocked. The intended future tier of each stays in `kFeatureMatrix` (the 3B model remains `Feature.largeLlm` = Pro by the size rule) so enabling Pro later is a configuration change, not a rewrite.
- [x] Add one switch (for example `proTierEnforced`, default `false`) in `EntitlementService` that, when off, treats Pro-gated features as unlocked for everyone, including existing Pro-gated items (warranty/engineering profiles, large LLM). No feature check outside `EntitlementService`/`FeatureGate`. Decide in this task whether the switch is a build/config constant or a runtime setting, and document how to turn it on.
- [x] Add `Feature` values and `kFeatureMatrix` rows for the chosen features (free / pro / enterprise / personal columns) with a unit test for every cell; no feature check outside `EntitlementService`/`FeatureGate`.
- [x] Set the `tier` of each new built-in profile to its intended future value (it has no effect while the switch is off) and remove the provisional `PRODUCT-DECISION` markers left by TPL-01/02/03.
- [x] While the switch is off, paywall entry points are hidden or inert (no purchase prompts); store product ids and prices are untouched; note the suppression in `docs/iap-products.md`.
- [x] Record the decision and its date in the Open Decisions table of `tasks/README.md`.

## Acceptance Criteria
- Each Phase 2 feature has a row in `kFeatureMatrix` and a passing cell test (`[LIC-05/AC1]`).
- The decision is recorded, with the date and who decided, in `tasks/README.md` Open Decisions (artifact).
- With the switch off, Ask, mind maps, Reminders export, the new profiles and the 3B model work on a Free entitlement, with no paywall shown (widget tests `[LIC-05/AC3]`).
- With the switch on, the same entry points show the paywall for ineligible tiers and work for eligible ones (widget tests `[LIC-05/AC4]`).
- Personal builds still unlock everything except organisation management (existing behaviour test stays green).
- `docs/iap-products.md` documents the switch and how to enable Pro later (artifact).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/LIC-05-phase2-feature-tiers · **Date:** 2026-10-18
- **Summary:** One switch, `proTierEnforced` (default `false`), threads through `FeatureAccess.resolve`, `LocalEntitlementService`, `maxModelTier` and `paywallEnabled`. Off: the Pro column is open to every plan, no paywall, Settings upgrade tile hidden; enterprise-only `managedProfiles` stays closed. It is a build constant (dart-define `VV_PRO_ENFORCED`, with `VV_COMMERCIAL`) exposed as `proTierEnforcedProvider`; the domain-level default is `true` so matrix unit tests stay literal. New `Feature` values: `quickCapture` (Free), `lectureProfile`, `salesProfile`, `interviewProfile`, `askNotes`, `mindMap`, `remindersExport` (intended Pro, PRODUCT-DECISION markers in `kFeatureMatrix`). `featureForProfile` maps the three profiles; the mind map tab gates on `Feature.mindMap` (paywall entry point `mindMap`). The placeholder markers in the three profile YAMLs are removed (tier `pro` stays; the matrix is the gate). No store, billing or product-id changes.
- **Deviation:** the intended tier of each feature (Pro except quick capture) is my proposal; the owner only decided "no Pro for now". Ask UI (ASK-04) and Reminders export (TSK-02) do not exist yet, so their rows are tested at the `featureProvider`/`ensureFeature` level.
- **Deferred / Unverified:** nothing needing a device. Pro enforcement in a real store build is untested by design (off).
- **Follow-ups:** ASK-04 and TSK-02 must call `ensureFeature` with `askNotes` / `remindersExport`.
- **Acceptance evidence:**
  - AC1: ✅ test: [LIC-05/AC1]; ci: nice -n 10 fvm flutter test test/unit/licensing
  - AC2: ✅ artifact: tasks/README.md
  - AC3: ✅ test: [LIC-05/AC3]; ci: nice -n 10 fvm flutter test test/widget/pro_tier_switch_test.dart
  - AC4: ✅ test: [LIC-05/AC4]; ci: nice -n 10 fvm flutter test test/widget/pro_tier_switch_test.dart
  - AC5: ✅ test: [LIC-05/AC5]; ci: nice -n 10 fvm flutter test test/unit/licensing/pro_tier_switch_test.dart
  - AC6: ✅ artifact: docs/iap-products.md
