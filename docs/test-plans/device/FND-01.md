# Device verification — FND-01 Initialize Flutter Repository & Code Standards

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-01/AC2] | 1. Connect a physical iPhone (iOS 16+), select a signing team in Xcode (Runner → Signing). 2. `cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <iphone-id>`. | App installs as "VaultVoice Dev" (orange icon, bundle `com.vaultvoice.vaultvoice.dev`), launches and shows "dev flavor". | _pending_ | _pending_ | | | |
| [FND-01/AC2] | 1. Connect a physical arm64 Android phone (API 26+), USB debugging on. 2. `cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <android-id>`. | App installs as "VaultVoice Dev" (orange icon, id `com.vaultvoice.vaultvoice.dev`), launches and shows "dev flavor". | _pending_ | _pending_ | | | |

## Notes / evidence
Host-side checks done without a device (Xcode/Android SDK were not installed on the authoring
machine): `fvm flutter analyze` → no issues; `fvm dart format --set-exit-if-changed .` clean;
`fvm flutter test` passes; iOS `project.pbxproj` passes `plutil -lint`. Native builds of the
flavors have **not** been compiled yet.
