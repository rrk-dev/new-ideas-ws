# LIC-01 — Entitlements & Feature Gating Framework

**Workstream:** Licensing | **Phase:** 2–3 | **Size:** S | **Depends on:** FND-02 | **Source:** §7
**Status:** todo
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-testing

## Goal
One central place that decides what Free / Pro / Enterprise users can do.

## Scope
- [ ] Entitlement model: `free`, `pro_annual`, `pro_lifetime`, `enterprise` with expiry.
- [ ] Feature flags mapped per §7:
  - Free: tiny/base Whisper, built-in Meeting summary export, one vault target.
  - Pro: high-accuracy Whisper, 3B+ LLM, custom templates, unlimited profiles, multiple routing rules.
  - Enterprise: Pro + managed templates/config.
- [ ] `featureProvider(Feature.x)` Riverpod API; paywall entry points.
- [ ] Graceful downgrade when Pro expires (existing custom profiles become read-only, not deleted).
- [ ] `// PRODUCT-DECISION`: master plan §7 says Free gets "small/tiny Whisper"; skills default `small.en` to Pro. Free LLM is capped at the 1B-class model on every device tier.
- [ ] Open question to resolve: are Warranty and Engineering built-in profiles Free or Pro? (§7 lists Warranties under Pro.)

## Acceptance Criteria
- Unit tests for every feature × tier combination; downgrade path tested.
