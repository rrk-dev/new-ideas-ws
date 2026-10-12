---
name: vv-licensing-iap
description: "Monetization code: Free/Pro/Enterprise entitlements and feature gating, paywall, StoreKit 2 and Play Billing purchases with offline grace, restore/refunds, enterprise signed license files, MDM managed configuration. Use for any Pro/feature check."
---

# Licensing, Purchases & Enterprise

## Entitlements (LIC-01)
```dart
enum Plan { free, proAnnual, proLifetime, enterprise }
class Entitlement { Plan plan; DateTime? expiresAt; DateTime verifiedAt; String source; Set<Feature> extra; }
enum Feature { highAccuracyStt, largeLlm, customTemplates, customProfiles, multiTarget,
               routingRules, builtinWarranty, builtinEngineering, managedProfiles, sideloadCustomModel }
```
- Single `EntitlementService` (keepAlive Riverpod) → `bool has(Feature)` + `Stream`.
  UI uses `ref.watch(featureProvider(Feature.x))`. **No other code inspects plans directly.**
- Mapping from master plan §7 lives in one table `feature_matrix.dart` with a unit test per
  cell. Free: tiny/base STT, meeting profile, 1 target. Pro: everything except managed.
  Enterprise: Pro + managed. Master plan §7 gives Free "small/tiny Whisper" — whether
  `small.en` is Free or Pro is a `// PRODUCT-DECISION` (skills default it to Pro). `builtinWarranty` /
  `builtinEngineering` tier is also a **product
  decision** — leave as a constant flagged `// PRODUCT-DECISION` and ask the user.
- Downgrade: custom profiles/templates/rules become read-only, extra targets disabled (not
  deleted); Pro-only models stay installed but can't be selected.

## Store purchases (LIC-02)
Products (configure identically in App Store Connect & Play Console):
`vv_pro_annual` (auto-renewable subscription, 1 year) and `vv_pro_lifetime` (non-consumable /
one-time product). Prices from §7 are set in consoles, never hard-coded.

### iOS — StoreKit 2 (on-device verification)
Implement a small Swift host API (Pigeon) instead of relying on generic plugin receipt
handling: `Product.products(for:)`, `product.purchase()`, `Transaction.currentEntitlements`
(only `.verified` results — StoreKit verifies the JWS signature on-device), `Transaction.updates`
listener started at launch (handles renewals, refunds `revocationDate`, family sharing),
`AppStore.sync()` for Restore. No server needed.

### Android — Play Billing
Google Play requires Play Billing Library **8+** for new apps/updates (since 31 Aug 2026).
`in_app_purchase_android` 0.5.x uses PBL 8 (compliant; PBL 9 is current) — or write a Kotlin host
API on the latest PBL: `queryProductDetailsAsync`, `launchBillingFlow`, `queryPurchasesAsync` (served from the Play
Store cache, works offline for recent data), **acknowledge within 3 days** of the purchase becoming
`PURCHASED` (not while `PENDING`) or it is refunded. Local verification: verify `originalJson` against `signature` using the app's Play
Console base64 RSA public key (embed obfuscated; accept that local checks are bypassable —
document in ADR). Optional stateless verification server is a privacy trade-off → ADR + user
approval before building one.

### Offline grace
Persist the last **successful** verification (encrypted settings). If it says *not entitled*
(expired, refunded, revoked) → Free immediately. Grace applies only when verification cannot run
(offline/store unavailable): subscription stays active while `now < expiresAt + 30 d` **and**
`now < lastVerifiedAt + 30 d`; lifetime stays active until a successful verification reports
revocation. Re-verify on
launch when online (through OS frameworks — not our gateway).
Test: sandbox/StoreKit config file (Xcode) purchase, renew (accelerated), expire, refund,
restore; Play license testers + test cards; airplane mode grace.

## Enterprise license (LIC-03) — design doc first (`docs/enterprise-licensing.md`)
License file `*.vvlicense` = JSON payload + Ed25519 signature (our enterprise signing key,
offline): `{format:1, license_id, org_id, org_name, seats, issued_at, expires_at, features[],
org_profile_pubkey (for signed profile packs), managed_config_defaults{}}`.
- Delivered via MDM managed config (base64) or file import. App verifies signature with pinned
  public key(s), checks expiry (+ 30-day grace with warnings from T-30d).
- Seats: no phone-home by default. Options for ADR: honor system + annual true-up (default),
  or customer-hosted license server on their network (allowlisted host only for that org).
- Internal CLI `tools/licensing/` to generate/sign/inspect licenses (key from secure storage,
  never committed). Tests: valid, tampered, expired, wrong key, future `issued_at`.

## Managed configuration (LIC-04)
- iOS: read `UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")`, observe
  `UserDefaults.didChangeNotification`. Android: `RestrictionsManager.applicationRestrictions`
  + `res/xml/app_restrictions.xml` schema, listen to `ACTION_APPLICATION_RESTRICTIONS_CHANGED` with a **runtime-registered** receiver
  (manifest receivers don't get it) and re-read on every app start.
- Keys (document in `docs/mdm-config.md`): `license` (base64), `profile_packs` (base64 list),
  `allowed_target_kinds`, `force_app_lock`, `audio_retention_days`, `network_disabled`,
  `lock_settings` (list), `disable_custom_models`.
- Managed values override user settings and render read-only in Settings (APP-03).
- Recording-related keys may only make recording stricter (force consent, shorter max duration).
  No key may start recording, hide indicators, or disable CallGuard/consent (SEC-09).
- Test with Android Test DPC and an iOS MDM test tenant (or Apple Configurator managed config).
