# In-app purchases (LIC-02)

Pro has two products: `vv_pro_annual` (auto-renewable, annual billing) and
`vv_pro_lifetime` (non-consumable / one-time, never consumed). Configure their
actual prices in App Store Connect and Play Console. Display strings always
come from StoreKit Product.displayPrice / Play formattedPrice.

## Store builds
The release lanes call `tools/release/build_release.sh`, which passes
`--dart-define=VV_COMMERCIAL=true` for both IPA and AAB. Development builds keep
the personal default unless the flag is explicitly supplied. To test commerce:

```sh
cd app
fvm flutter run --flavor dev -t lib/main_dev.dart --dart-define=VV_COMMERCIAL=true
```

Android additionally requires `VV_PLAY_PUBLIC_KEY` in the build environment:
the base64 RSA public licensing key from the **same** Play Console app. The
release script refuses an unset value; Gradle embeds a reversed representation
in BuildConfig, never source. Obfuscation is only friction: the public key is
not a secret, and client verification is bypassable on compromised devices.
Never place service-account credentials, signing keys or purchase tokens in
Dart defines, source, logs, screenshots or task evidence. Release CI supplies
the key from its `VV_PLAY_PUBLIC_KEY` secret to the build step.

The annual Play base plan must use P1Y, auto-renewal, and a regular single price
phase. Promotional/introductory offers are not offered in v1; this avoids
showing a trial price as the annual recurring price. Configure one such base
plan per region. Lifetime uses the ordinary one-time purchase offer.

## Local and sandbox testing
Open the iOS project in Xcode; Edit Scheme → Run → Options → StoreKit
Configuration → Runner/VaultVoice.storekit. Add the existing file to the scheme
via the file picker if it is not listed. Its 1.00 / 2.00 amounts are synthetic
local testing data, unrelated to production prices. Enable interrupted/pending,
renewal/expiry and refund simulations in Xcode's transaction manager. For real
sandbox runs disable the local configuration and use TestFlight/store products.
Minimum deployment target is iOS 16.4.

Apple Family Sharing is accepted for verified entitlements and should be enabled
for eligible products in the console. Play family library does not share IAP.
Lifetime takes priority over active annual ownership; refunding lifetime falls
back to an annual purchase that still verifies.

StoreKit starts Transaction.updates at native launch, only accepts verified
transactions, finishes deliveries, and refreshes current entitlements. Restore
is explicitly user-triggered AppStore.sync(). Play connects at launch, queries
both product types, checks package/product/state/signature, and acknowledges
PURCHASED deliveries immediately before granting. Failed acknowledgements retry
on launch, foreground, store updates and hourly while running. A user who never
returns after a failed acknowledgement may still get Play's automatic refund
at three days; no client-only integration can guarantee a background retry
while an app remains killed. Pending purchases are never acknowledged/granted.

Last successful verification persists in the existing SEC-01 encrypted settings
DB (no schema migration or receipt/token storage). Offline errors preserve that
snapshot. Subscriptions remain active strictly before both paid expiry +30d and
last verification +30d; lifetime survives until a successful check revokes it.
Verified expiry/empty ownership/invalid verification downgrades immediately.
The adapter checks OS reachability before refreshing to avoid converting an
airplane-mode cached empty response into a definitive revocation.

Play BillingClient exposes no signed annual expiry. This implementation uses
a bounded one-day verification lease and checks hourly/foreground, rather than
claiming purchaseTime is a renewal timestamp. See
[ADR-LIC-02](adr/ADR-LIC-02-store-verification.md) for limitations, alternatives
and the local-verification privacy decision. StoreKit uses exact signed expiry.
Neither OS reachability nor cached client queries prove a server roundtrip;
revocations can be delayed by OS store caches. No server freshness guarantee is
claimed. Device/sandbox evidence remains pending in
[test checklist](test-plans/device/LIC-02.md).
