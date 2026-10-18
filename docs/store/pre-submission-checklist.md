# Pre-submission checklist (SEC-06)

Run before every store submission and copy into the release record. Items
marked ⏳ need a human with store access, a Mac with the signing identity, or
a device; the repository work for them is done.

## Automated (CI)
- [x] `tools/ci/check_store_privacy.sh` — manifests, usage strings, Android permissions, copy, policy link
- [x] `tools/ci/check_recording_policy.sh --require-merged-manifest` — no call capture (SEC-09)
- [x] `tools/ci/check_egress.sh` — no network outside the gateway (SEC-02)
- [x] `tools/ci/check_packages.sh` — no analytics/ads/crash packages
- [x] `tools/ci/check_egress.sh` also rejects integration hosts (Todoist, Notion, OpenAI and similar) and OAuth/credential code by name (SEC-11)

## iOS
- [ ] ⏳ Archive → Generate Privacy Report; matches `docs/store/privacy-manifest.md` (includes the LumenWidgets and Share extension reports and the System boot time `35F9.1` entry, SEC-11)
- [ ] ⏳ Reminders strings and App Group appear exactly as listed in `docs/test-plans/device/SEC-11.md` (SEC-11 sign-off row)
- [ ] ⏳ App Privacy: **Data Not Collected** saved in App Store Connect
- [ ] ⏳ Reviewer notes from `docs/store/reviewer-notes.md` pasted
- [ ] ⏳ Privacy policy URL set (business-provided; the app also bundles the text)
- [ ] ⏳ Listing, keywords and screenshots checked against `docs/store/listing.md` (no call-recording wording)
- [ ] ⏳ TestFlight external review passed

## Android
- [ ] ⏳ Data Safety: **No data collected / shared** saved in Play Console
- [ ] ⏳ Foreground service declaration pasted (`docs/play-console/fgs-declaration.md`)
- [ ] ⏳ Permissions declarations list no call-log/phone-state permissions (merged manifest checked by CI)
- [ ] ⏳ Privacy policy URL set
- [ ] ⏳ Play pre-launch report passed (no policy warnings)

## Content
- [ ] ⏳ Business/legal supplied the final privacy policy text; `app/assets/legal/privacy_policy.md` replaced
- [ ] ⏳ Legal reviewed the consent wording (SEC-07) and the store copy
