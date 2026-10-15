# Device verification — LIC-02 In-App Purchases

No devices or store credentials available to implementer. Every row below is
pending (⏳); no sandbox result is claimed. Capture screenshots and logs containing
only product IDs/status (never tokens, signatures or user content).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LIC-02/AC1] | Select VaultVoice.storekit in the dev scheme; run commercial build; buy annual; accelerate renewal; expire; refund; relaunch; restore; repeat lifetime and refund. Inject pending/cancel/unverified. | Localized store price; verified Pro; renewal extends expiry; expiry/refund Free immediately; restore recovers current entitlement; pending/cancel/unverified never grant. | iPhone, Xcode StoreKit testing | iOS 16+ | ⏳ | | |
| [LIC-02/AC1] | In TestFlight sandbox buy annual and lifetime; renew annual, expire/refund/revoke; force-kill/relaunch; restore with same account and family-sharing account. | Verified-only updates at launch; no duplicate transaction grant; lifetime preferred; refunded lifetime falls back to active annual; family sharing follows console setting. | iPhone | iOS 16.0 and current iOS | ⏳ | | |
| [LIC-02/AC1] | Build a minified Play release; confirm DataTransport/location absent in resolved dependencies, logger disables without crash and egress uses only store services; install internal-track release with console public key; license tester buys annual/lifetime with test cards; exercise pending then approved/declined, cancel, accelerated renew/expire, refund+revoke, restore/reinstall, disconnect during acknowledgement. | Valid signature/package/product/PURCHASED only; acknowledgement immediately, retry on launch/resume/hourly; no consumption; no grant pending; successful empty query Free; missing/wrong key fails closed; store prices only. | ARMv8.2+dotprod Android phone | API 26+ and current Android | ⏳ | | |
| [LIC-02/AC2] | Verify annual; airplane mode; relaunch; set clock before/at expiry+30d and verifiedAt+30d; repeat lifetime; reconnect after refund. | Annual survives strictly within both limits, Free at either boundary; no lastVerifiedAt extension while offline; lifetime survives outage then successful revoked/empty result Free; clock rollback before verifiedAt fails closed. | iPhone | iOS 16+ | ⏳ | | |
| [LIC-02/AC2] | Verify annual/lifetime; airplane mode; relaunch; exercise 30-day verifiedAt limit; reconnect after refund. Repeat clock rollback and process kill during cache write. | Cached annual bounded by last verification +30d and conservative Play lease+30d; lifetime survives outage; successful empty result immediately Free; cache write atomic through encrypted DB. | ARMv8.2+dotprod Android phone | API 26+ | ⏳ | | |

## Build prerequisites
Xcode/CocoaPods/iOS runtimes and Android SDK/JDK/NDK must be supplied by the
coordinator/device lab. Do not install tools or claim PASS without actual runs.
Store consoles must configure the exact product IDs and annual billing period;
production prices are console-managed. See ADR-LIC-02-store-verification.md for
the limitation of local Play expiry and revocation freshness.
