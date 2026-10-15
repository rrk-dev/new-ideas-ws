# LIC-02 — In-App Purchases (Annual + Lifetime) with Offline Entitlement

**Workstream:** Licensing | **Phase:** 3–4 | **Size:** M | **Depends on:** LIC-01 | **Source:** §7 ($29.99/yr, $49.99 lifetime) + Gap (offline validation)
**Status:** review
**Skills:** vv-task-workflow, vv-licensing-iap, vv-privacy-security, vv-decision-records, vv-testing

## Goal
Sell Pro through the stores without a backend and without breaking offline use.

## Scope
- [x] iOS: Swift StoreKit 2 host API via Pigeon; Android: `in_app_purchase_android` on Play Billing Library ≥ 8 (Play requirement) or a Kotlin host API. Products: auto-renewable annual subscription + non-consumable lifetime.
- [x] On-device verification: StoreKit 2 JWS transactions (verified locally); Play — evaluate local signature check vs minimal stateless verification server (document privacy trade-off; recommendation: on-device where possible).
- [x] Offline grace per `vv-licensing-iap` → Offline grace (verified expiry/refund ⇒ Free immediately; grace only when verification can't run).
- [x] Restore purchases; family sharing decision; refund/revocation handling.
- [x] Paywall screen.

## Acceptance Criteria
- Sandbox purchase, restore, renewal, expiry and refund flows tested on both stores.
- Pro remains active in airplane mode within grace period.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/lic · **Date:** 2026-10-15
- **Summary:** Pro annual + lifetime purchases without a backend: StoreKit 2 (Swift, Pigeon `PurchaseApi`, JWS verified on device) and a Kotlin Play Billing host API (local signature/package/product check, acknowledge with retry, no consumption); Dart `PurchaseService` verifies, persists entitlements, applies offline grace (verified expiry/refund → Free immediately; grace only when verification cannot run, bounded by lastVerifiedAt+30d), restore via Settings, paywall screen (`/pro`, store-localized prices). Decisions in `docs/adr/ADR-LIC-02-store-verification.md` (Proposed), `docs/in-app-purchases.md`, `docs/billing-sdk-audit.md`. Enterprise layer untouched.
- **Gates:** format 0 changed; analyze 0 issues; unit tests pass (`test/unit/licensing`, settings, security); `tasks.py validate` run.
- **Acceptance evidence:**
  - AC1: ⏳ test: [LIC-02/AC1]; device: docs/test-plans/device/LIC-02.md
  - AC2: ⏳ test: [LIC-02/AC2]; device: docs/test-plans/device/LIC-02.md
- **Decisions:** ADR-LIC-02-store-verification (Proposed): on-device verification, no server.
- **Follow-ups:** sandbox purchase/restore/renewal/expiry/refund runs on iOS and Android devices and store console product setup (human; ⏳ rows); Play expiry/revocation freshness limit of local verification (see ADR); Android/iOS native builds not compiled in this environment; enterprise plan out of scope.
