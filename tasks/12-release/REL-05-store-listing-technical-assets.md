# REL-05 — Store Listing Technical Assets & Submission

**Workstream:** Release | **Phase:** 4 | **Size:** S | **Depends on:** REL-01, SEC-06 | **Source:** §5 Phase 4 (app store media assets)
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release, vv-privacy-security, vv-licensing-iap

## Goal
Engineering side of store submission (marketing copy is out of scope).

## Scope
- [x] Automated screenshot generation (integration_test + fastlane snapshot/screengrab) for all required device sizes.
- [x] App icons, launch screens, feature graphic per flavor.
- [x] Store metadata in repo (fastlane `metadata/`), IAP product configuration in both consoles.
- [x] Reviewer notes: demo instructions, offline model explanation, background-mode justification, and an explicit statement that the app does not record phone/VoIP calls and only records after a user tap with a visible indicator.

## Acceptance Criteria
- App submitted and approved on both stores.

## Completion Notes
- **Agent:** Cursor · **Branch:** task/REL-05-store-listing · **Date:** 2026-10-15
- **Base:** origin/integration/wave-4 (`b398114`); does not stack on REL-04.
- **Summary:** Engineering store-listing pack without compiling unused platforms. `tools/release/store_screenshot_sizes.json` pins ASC sizes retrieved 2026-10-15 (iPhone 1206×2622, iPad 2064×2752, Android 1080×1920, feature graphic 1024×500, hi-res icon 512×512). Flutter integration test `app/integration_test/store_screenshots_test.dart` + host widget/unit tests seed synthetic demo data (`Speaker A`/`Speaker B`, `Sample weekly planning` — no real people). Capture: `tools/release/capture_store_screenshots.sh` (exit 2 with no device; no IPA/APK compile) wired from `Fastfile.store` + Snapfile/Screengrabfile. Play graphics from `gen_store_graphics.py` (brand `#3F51B5`). Flavor splash YAML (`flutter_native_splash-{dev,prod}.yaml`) and Android `splash_background` color overlays; iOS LaunchScreen uses the prod seed. `fastlane/metadata/**` copy is `[PRODUCT]` placeholders. Reviewer notes (engineering) cover no phone/VoIP recording, user-tap start, Hugging Face models, `audio`/`processing` background modes, Android microphone FGS, and `store_demo_silence.wav`. IAP `vv_pro_annual` / `vv_pro_lifetime` in `docs/iap-products.md`. Checklist: `docs/release-checklist.md` Store listing (REL-05). Walkthrough: `docs/store-listing.md`.
- **Gates:** app: `dart format` 0 changed, `flutter analyze` 0 issues, `dart analyze --fatal-infos` 0 issues, `flutter test --concurrency=2` **1359 passed / 52 skipped** (macOS goldens); `tools/ci/check_codegen.sh` OK (no diff); `python3 -m pytest tools/ci/tests tools/release/tests -q` **110 passed**; `check_recording_policy.sh` OK; `check_egress.sh` OK. Did not run `flutter build` or `flutter_native_splash:create`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [REL-05/AC1]; device: docs/test-plans/device/REL-05.md; artifact: docs/store-listing.md
- **Decisions:**
  - // PRODUCT-DECISION: required iPhone class is Dynamic Island medium 1206×2622 (iPhone 16 Pro); iPad 13" 2064×2752 because TARGETED_DEVICE_FAMILY includes iPad.
  - // PRODUCT-DECISION: Play feature graphic and 512 icon are solid brand-color placeholders (`#3F51B5` = AppColors.seed) until product supplies artwork.
  - // PRODUCT-DECISION: iOS LaunchScreen uses the prod seed for both flavors until `flutter_native_splash:create` is run on a machine with Xcode; Android splash color is per-flavor.
  - // PRODUCT-DECISION: store screenshot speakers are "Speaker A"/"Speaker B" (not the library fixture names).
  - IAP identifiers `vv_pro_annual` (annual subscription) and `vv_pro_lifetime` (one-time) are the user-decided products; prices/copy stay `[PRODUCT]`.
  - Privacy nutrition labels / Data Safety stay with SEC-06 (still a soft dep).
- **Follow-ups:**
  - Product replaces `[PRODUCT]` metadata and the solid Play graphics before REL-06 submission.
  - First screenshot capture needs iPhone 16 Pro + iPad Pro 13" simulators and a 1080×1920 Android emulator (`docs/test-plans/device/REL-05.md`).
  - Run `flutter_native_splash:create --flavor {dev,prod}` when replacing splash YAML/PNGs.
  - SEC-06: privacy URL + nutrition labels / Play Data Safety must land before submission.
  - Console: create `vv_pro_annual` and `vv_pro_lifetime` in App Store Connect and Play Console; submit; approval is the remaining AC.
