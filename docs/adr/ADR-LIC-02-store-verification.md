# ADR-LIC-02 — On-device store verification

Status: Proposed (platform builds and store/device measurements pending)
Date: 2026-10-14

## Question and constraints
Sell annual `vv_pro_annual` and non-consumable `vv_pro_lifetime` without a
backend, telemetry, content transmission or hard-coded production prices.
iOS 16+, Android 26+, arm64; Flutter 3.47.7, Pigeon 29.0.8.

## Options and criteria
Criteria chosen before implementation: privacy 40%, offline behavior 25%,
verification correctness 25%, maintenance/integration cost 10%.

1. StoreKit 2 plus a Kotlin Play Billing host: OS verification on Apple;
   local Play RSA signature verification; no app HTTP traffic. Typed Pigeon
   boundaries and fake stores support deterministic tests.
2. Generic Flutter IAP plugin: less native code, but still needs a custom
   StoreKit 2 verified-transaction boundary and Play signature verification.
3. Stateless verification server: authoritative Play subscription expiry and
   faster revocation; sends purchase tokens/device IPs to an additional service,
   needs service credentials and operations. Outside the authorized scope.

## Decision
Implement option 1. Play Billing pinned to 9.1.0 (Google SDK terms; DataTransport telemetry
and unused location dependencies excluded per docs/billing-sdk-audit.md); StoreKit is an OS framework. StoreKit trusts only `.verified` transactions,
filters revoked/upgraded/expired entries, observes updates from launch and
finishes verified deliveries. Restore calls AppStore.sync().

Play checks the original JSON signature with the console RSA public key,
package name, exact product allowlist and PURCHASED state, then acknowledges
before delivery; never consumes lifetime. Missing key or invalid signatures
fail closed. Key comes from VV_PLAY_PUBLIC_KEY build environment, never source.
The signature format uses SHA1withRSA because that is Play's existing signed
purchase protocol (verification only; we do not create SHA-1 signatures).
Local checks remain patchable on compromised devices. The app does not claim
server-equivalent fraud protection.

### Play expiry limitation
BillingClient Purchase has no signed subscription expiry field. Do not invent
an annual expiry from purchaseTime: renewals do not provide a reliable new
period start. A successful query of current purchases confirms an active
subscription at query time; assign a conservative one-day verification lease,
refresh hourly while running and on foreground/launch. On store unavailability,
apply the normal 30-day cap from last successful verification. A successful
empty query downgrades immediately. This lease is not the contractual annual
expiry and can grant at most one day after an unobserved expiry before the
next query (or the configured offline grace while unavailable).

// PRODUCT-DECISION: use this bounded Play lease with local verification;
authoritative paid-through timestamps require the server option and a future
explicit product/privacy decision. StoreKit uses its exact signed expiry.

// PRODUCT-DECISION: accept verified Apple family-shared entitlements; enable
Family Sharing for eligible products in App Store Connect. Play family library
does not share these in-app purchases. A user with both products receives
lifetime; refunding lifetime falls back to a remaining active annual plan.

## Persistence and failure behavior
Persist the last successful snapshot in SEC-01's encrypted settings table.
Unavailable store calls do not replace its timestamp. Verified expired, empty,
refunded or invalid-verification results replace it with Free immediately.
Annual offline access ends strictly before both expiry + 30 days and verifiedAt
+ 30 days. Lifetime survives outages until a successful revocation/empty query.
Future cache verification timestamps fail closed (clock rollback).

## Evidence and sources
API inspection on 2026-10-14:
- https://developer.apple.com/documentation/storekit/transaction/currententitlements
- https://developer.apple.com/documentation/storekit/transaction/updates
- https://developer.apple.com/documentation/storekit/appstore/sync()
- https://developer.android.com/google/play/billing/integrate
- https://developer.android.com/google/play/billing/security
- https://developer.android.com/google/play/billing/release-notes

Dart fake-store, cache, grace, refund and UI tests accompany this task. No
platform build, signing, sandbox/device timing or performance result is claimed:
Xcode/CocoaPods and Android SDK/JDK are absent. Device checklist records these
remaining measurements. No server, network permissions, certificates, private
keys, model files or content logs are introduced.
