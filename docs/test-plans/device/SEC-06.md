# Device verification — SEC-06 Store Privacy Compliance

Automated checks: `tools/ci/check_store_privacy.sh`, `[SEC-06/AC1]` in
`tools/ci/tests/test_store_privacy.py`, `app/test/widget/privacy_policy_test.dart`.
The store steps below need a Mac with signing, App Store Connect and Play
Console access. Leave Result, Date, and Tester blank until run.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-06/AC1] | 1. Archive the iOS app. 2. Xcode Organizer → Generate Privacy Report. 3. Compare with `docs/store/privacy-manifest.md`. | Report lists only the declared required-reason APIs; no tracking domains; no collected data. | Mac with Xcode | Xcode 16+ | ⏳ | | |
| [SEC-06/AC1] | 1. Upload to TestFlight. 2. Submit for external review with `docs/store/reviewer-notes.md`. | Review passes with no privacy-manifest or 2.5.2 rejection. | iPhone 12+ | iOS 17/18 | ⏳ | | |
| [SEC-06/AC1] | 1. Upload to Play internal/closed track. 2. Open the pre-launch report. 3. Open Policy status. | No policy warnings; Data Safety "No data collected" accepted; no call-log/phone-state declaration needed. | Play pre-launch devices | Android 14+ | ⏳ | | |
| [SEC-06/AC1] | 1. Open Settings → About → Privacy policy in airplane mode. | The policy text shows; nothing opens in a browser. | Any | iOS 17 / Android 14 | ⏳ | | |
