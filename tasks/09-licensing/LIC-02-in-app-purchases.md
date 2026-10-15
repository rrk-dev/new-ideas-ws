# LIC-02 — In-App Purchases (Annual + Lifetime) with Offline Entitlement

**Workstream:** Licensing | **Phase:** 3–4 | **Size:** M | **Depends on:** LIC-01 | **Source:** §7 ($29.99/yr, $49.99 lifetime) + Gap (offline validation)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-licensing-iap, vv-privacy-security, vv-decision-records, vv-testing

## Goal
Sell Pro through the stores without a backend and without breaking offline use.

## Scope
- [ ] iOS: Swift StoreKit 2 host API via Pigeon; Android: `in_app_purchase_android` on Play Billing Library ≥ 8 (Play requirement) or a Kotlin host API. Products: auto-renewable annual subscription + non-consumable lifetime.
- [ ] On-device verification: StoreKit 2 JWS transactions (verified locally); Play — evaluate local signature check vs minimal stateless verification server (document privacy trade-off; recommendation: on-device where possible).
- [ ] Offline grace per `vv-licensing-iap` → Offline grace (verified expiry/refund ⇒ Free immediately; grace only when verification can't run).
- [ ] Restore purchases; family sharing decision; refund/revocation handling.
- [ ] Paywall screen.

## Acceptance Criteria
- Sandbox purchase, restore, renewal, expiry and refund flows tested on both stores.
- Pro remains active in airplane mode within grace period.
