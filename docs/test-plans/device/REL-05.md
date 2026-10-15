# Store submission — REL-05 Store Listing Technical Assets

Host evidence: `[REL-05/AC1]` in `tools/release/tests/test_store_listing.py` and
`app/test/{unit,widget}/` store screenshot tests. Pixel sizes:
`tools/release/store_screenshot_sizes.json` (App Store Connect screenshot
specifications, retrieved 2026-10-15). Capture needs a simulator/emulator;
store approval needs consoles. No devices on the authoring machine.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [REL-05/AC1] | 1. Boot iPhone 16 Pro simulator. 2. `python3 tools/release/gen_store_graphics.py`. 3. `bash tools/release/capture_store_screenshots.sh ios`. 4. Confirm PNGs under `app/ios/fastlane/screenshots/en-US/` are 1206×2622 (iPhone) and repeat on iPad Pro 13-inch (M4) for 2064×2752. | Five shots (onboarding, record, library, transcript, settings). Library shows "Sample weekly planning"; transcript speakers are Speaker A / Speaker B; no photographs of people. | iPhone 16 Pro simulator; iPad Pro 13-inch (M4) simulator | iOS 18 | ⏳ | | |
| [REL-05/AC1] | 1. Boot a 1080×1920 Android emulator. 2. `bash tools/release/capture_store_screenshots.sh android`. 3. Confirm `featureGraphic.png` is 1024×500 and `icon.png` is 512×512. | Phone screenshots 1080×1920 in `app/android/fastlane/metadata/android/en-US/images/phoneScreenshots/`; feature graphic and hi-res icon present. | Android emulator (1080×1920) | API 34 | ⏳ | | |
| [REL-05/AC1] | Replace `[PRODUCT]` metadata with product copy. Create IAP `vv_pro_annual` and `vv_pro_lifetime` in both consoles. Submit with reviewer notes (`notes.txt` / `review_notes.txt`). | App Store and Play listings accepted; reviewer can import `store_demo_silence.wav` without speaking; no call-recording rejection. | App Store Connect + Play Console | — | ⏳ | | |

## Notes / evidence
Locally verified: pytest `tools/release/tests/test_store_listing.py`, Dart
`[REL-05/AC1]` unit/widget tests, PNG IHDR sizes, 16 kHz mono demo WAV.
`flutter build` and `flutter_native_splash:create` were **not** run (disk /
no devices). First capture on a simulator is the real screenshot run.
