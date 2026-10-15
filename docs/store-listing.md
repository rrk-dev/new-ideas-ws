# Store listing technical assets (REL-05)

How screenshots, icons, splash, metadata folders, IAP IDs, and reviewer
notes are produced. Marketing copy is product-owned (`[PRODUCT]`).

## Screenshots (no real people)

Synthetic demo data lives in `app/test/helpers/store_demo_data.dart`:
speakers **Speaker A** / **Speaker B**, title **Sample weekly planning**,
no photos, no NetworkImage. The Flutter integration test
`app/integration_test/store_screenshots_test.dart` pumps real screens
with that seed and writes PNGs.

Sizes: `tools/release/store_screenshot_sizes.json` (App Store Connect
screenshot specifications, retrieved 2026-10-15).

| Platform | Required size | Device / asset |
|---|---|---|
| iPhone | 1206 × 2622 | iPhone 16 Pro (Dynamic Island, medium) |
| iPad | 2064 × 2752 | iPad Pro 13-inch (M4) — app is iPhone+iPad |
| Android phone | 1080 × 1920 | emulator |
| Play feature graphic | 1024 × 500 | `featureGraphic.png` |
| Play hi-res icon | 512 × 512 | `icon.png` |

Capture (needs a simulator/emulator; **not** run in this clone):

```bash
python3 tools/release/gen_store_graphics.py
bash tools/release/capture_store_screenshots.sh ios
bash tools/release/capture_store_screenshots.sh android
```

Fastlane:

- iOS: `app/ios/fastlane/Snapfile` + `Fastfile.store` lane `screenshots`
- Android: `app/android/fastlane/Screengrabfile` + `Fastfile.store` lane `screenshots`

Output trees:

- iOS: `app/ios/fastlane/screenshots/en-US/`
- Android: `app/android/fastlane/metadata/android/en-US/images/phoneScreenshots/`

Do **not** photograph testers, stock-photo people, or real transcripts.

## Icons and launch screens (per flavor)

| Flavor | Launcher icons | Native splash config |
|---|---|---|
| `dev` | `flutter_launcher_icons-dev.yaml` → `assets/icon/icon_dev.png` | `flutter_native_splash-dev.yaml` |
| `prod` | `flutter_launcher_icons-prod.yaml` → `assets/icon/icon_prod.png` | `flutter_native_splash-prod.yaml` |

Regenerate icons (when replacing the PNGs):

```bash
cd app && fvm dart run flutter_launcher_icons -f flutter_launcher_icons-prod.yaml
cd app && fvm dart run flutter_launcher_icons -f flutter_launcher_icons-dev.yaml
```

Regenerate splash (when replacing colors/image):

```bash
cd app && fvm dart run flutter_native_splash:create --flavor prod
cd app && fvm dart run flutter_native_splash:create --flavor dev
```

Those generators emit iOS/Android native files. Do not run them unless
the source PNGs or YAML actually changed; they rewrite many platform files.

iOS launch: `app/ios/Runner/Base.lproj/LaunchScreen.storyboard` (white +
LaunchImage). Android: `launch_background.xml` plus `splash_color.xml`
per flavor (`#3F51B5` prod, `#5C6BC0` dev).

## Metadata folders

Copy is `[PRODUCT]` placeholders. Do not invent marketing claims.

```
app/ios/fastlane/metadata/en-US/
  name.txt, subtitle.txt, description.txt, keywords.txt,
  promotional_text.txt, release_notes.txt, support_url.txt,
  marketing_url.txt, privacy_url.txt
app/ios/fastlane/metadata/review_information/
  notes.txt          # engineering reviewer notes (not placeholders)
  demo_user.txt, demo_password.txt, email_address.txt, phone_number.txt
app/android/fastlane/metadata/android/en-US/
  title.txt, short_description.txt, full_description.txt,
  video.txt, changelogs/default.txt
  images/{featureGraphic.png,icon.png,phoneScreenshots/}
```

Privacy nutrition labels / Data Safety (SEC-06) are **not** authored here.
URLs in `privacy_url.txt` stay placeholders until SEC-06 publishes the
policy.

## IAP

See `docs/iap-products.md`. Identifiers: `vv_pro_annual`,
`vv_pro_lifetime`.

## Reviewer notes (engineering)

`app/ios/fastlane/metadata/review_information/notes.txt` and
`app/android/fastlane/metadata/android/en-US/review_notes.txt` cover:

- No call / VoIP recording (SEC-09)
- Recording starts only after an explicit user tap
- Models download from Hugging Face on first launch (user-initiated)
- Background modes: audio (recording) and processing (on-device jobs)
- Android FGS `microphone` while recording
- Demo import: `app/test/fixtures/audio/store_demo_silence.wav`

## Release checklist

`docs/release-checklist.md` → Store listing (REL-05) section.
