# LIC-01 — Entitlements & Feature Gating Framework

**Workstream:** Licensing | **Phase:** 2–3 | **Size:** S | **Depends on:** FND-02 | **Source:** §7
**Status:** review
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-testing

## Goal
One central place that decides what Free / Pro / Enterprise users can do.

## Scope
- [x] Entitlement model: `free`, `pro_annual`, `pro_lifetime`, `enterprise` with expiry.
- [x] Feature flags mapped per §7:
  - Free: tiny/base Whisper, built-in Meeting summary export, one vault target.
  - Pro: high-accuracy Whisper, 3B+ LLM, custom templates, unlimited profiles, multiple routing rules.
  - Enterprise: Pro + managed templates/config.
- [x] `featureProvider(Feature.x)` Riverpod API; paywall entry points.
- [x] Graceful downgrade when Pro expires (existing custom profiles become read-only, not deleted).
- [x] `// PRODUCT-DECISION`: master plan §7 says Free gets "small/tiny Whisper"; skills default `small.en` to Pro. Free LLM is capped at the 1B-class model on every device tier.
- [x] Open question to resolve: are Warranty and Engineering built-in profiles Free or Pro? (§7 lists Warranties under Pro.)

## Acceptance Criteria
- Unit tests for every feature × tier combination; downgrade path tested.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LIC-01-entitlements · **Date:** 2026-10-13
- **Summary:** Entitlement model and feature gating in `app/lib/features/licensing/`:
  `domain/entitlement.dart` (`Plan` free/proAnnual/proLifetime/enterprise, `Tier`, `Feature`,
  immutable `Entitlement` with `expiresAt`/`verifiedAt`/`source`/`extraFeatures`; expired or
  expiry-less annual/enterprise fails closed to Free, lifetime never expires),
  `domain/feature_matrix.dart` (the single feature × tier table, every cell `// PRODUCT-DECISION`,
  `DistributionMode` + `VV_COMMERCIAL` dart-define, `maxModelTier`), `domain/feature_access.dart`
  (resolved snapshot + downgrade policy: `AccessLevel` full/readOnly/disabled for custom profiles,
  templates, routing rules, vault targets beyond the first, installed Pro models),
  `domain/entitlement_service.dart` + `data/local_entitlement_service.dart` (broadcast stream,
  timer fires at expiry, `refresh()` for clock jumps, `update()` for LIC-02/LIC-03 sources),
  `data/licensing_providers.dart` (`distributionModeProvider`, keepAlive `entitlementServiceProvider`,
  `featureAccessStateProvider`, `featureProvider(Feature)`, `modelAccessProvider`,
  `entitlementSummaryProvider` = Settings hook (plan, effective plan, expiry, downgraded),
  `paywallPresenterProvider` defaulting to `NoPaywallPresenter`), `domain/paywall.dart`
  (`PaywallRequest`, `PaywallEntryPoint`), `presentation/feature_gate.dart` (`ensureFeature()` paywall
  entry point + `FeatureGate` widget). No store code (LIC-02), no persistence (LIC-02 persists
  verifications), Settings UI untouched.
- **Personal vs commercial (switchable):** `--dart-define=VV_COMMERCIAL=true` turns on the Free /
  Pro / Enterprise columns. Default (flag unset/false) = personal build: every feature except
  `managedProfiles` is enabled on every plan, Pro-tier catalog models are selectable, no paywall is
  ever shown; enterprise-only items still need an enterprise entitlement. Chosen because the user has
  not decided personal vs commercial: the default never locks the owner out of anything, and
  switching to tiers is one build flag (the commercial matrix is fully implemented and tested).
- **PRODUCT-DECISIONs (need the user):** (1) personal default above; (2) `small`/`small.en` Whisper
  = Pro in commercial builds (skills default; §7 says Free gets small/tiny); (3) built-in Warranty
  and Engineering profiles = Pro (§7 lists Warranties under Pro; Engineering unspecified);
  (4) Free LLM capped at the 1B class on every device tier (`largeLlm` = Pro); (5) custom-model
  sideload = Pro; (6) managed profiles = Enterprise only in every build; (7) enterprise-tier catalog
  models need an enterprise licence in every build. All are single cells in `feature_matrix.dart`.
- **Gates:** build_runner (no unrelated diffs); `dart format --set-exit-if-changed` 0 changed;
  `flutter analyze` + `dart analyze` (riverpod_lint) 0 issues; `flutter test` all pass (116 new
  licensing unit tests + 2 widget tests); `pytest tools/ci/tests` 46 passed / 1 skipped;
  `check_recording_policy.sh` OK; `check_egress.sh` OK; `tasks.py validate` 0 problems.
  Mutation check: flipping `smallStt` Free cell to `true` fails `[LIC-01/AC1] smallStt × free`.
- **Acceptance evidence:**
  - AC1: ✅ test: [LIC-01/AC1]
- **Decisions:** none (no technology choice; product choices listed above as PRODUCT-DECISIONs).
- **Follow-ups:** none new — LIC-02 persists verified entitlements, applies offline grace, calls
  `EntitlementService.update` and overrides `paywallPresenterProvider`; LIC-03 maps licence
  `features[]` to `Entitlement.extraFeatures`; APP-xx Settings reads `entitlementSummaryProvider`;
  PRF/EXP/MDL screens gate via `featureProvider` / `FeatureAccess` access levels.

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[LIC-01/AC1]` (`feature_matrix_test.dart`, `downgrade_test.dart`). Every `Feature` × `Plan` × `DistributionMode` is asserted against an expected table that is not the production map. Commercial Free is off for Pro features; Enterprise alone has `managedProfiles`; limits are one vault target on Free and read-only custom profiles/templates/rules after expiry. Annual without expiry fails closed; lifetime does not expire; `featureProvider` follows `update` and a clock jump. Checked `smallStt × free (commercial)` fails when that cell is flipped to `true`.
- **Adversarial checks:** Expired Pro keeps custom data but `AccessLevel.readOnly` / disabled for extra vault targets and Pro models. Personal build (`VV_COMMERCIAL` unset) enables every non-managed feature and never shows a paywall — the test locks that default. No store SDK in this task. `tasks.py verify LIC-01 --run` short-circuits because dependencies are not `done`; the tagged tests passed in the full suite.
- **Skill/rule compliance:** One matrix in `feature_matrix.dart`. §7 cells that conflict with the skill (`small` Whisper, Warranty/Engineering profiles) are `// PRODUCT-DECISION` comments, not silent changes. Downgrade does not delete profiles. Paywall is an entry point (`ensureFeature` / `FeatureGate`) with `NoPaywallPresenter` until LIC-02.
- **Issues found:** none
- **Pending for done:** dependency FND-02 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
