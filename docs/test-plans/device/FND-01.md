# Device verification — FND-01 Initialize Flutter Repository & Code Standards

AC2 is a **simulator / emulator** run. Physical-device runs belong to GATE-01, not this task.
The app ships arm64 only (`abiFilters arm64-v8a`; the iOS native framework has an arm64
simulator slice), so use an Apple Silicon Mac with an **arm64** iOS simulator and an
**arm64-v8a** Android system image.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-01/AC2] | 1. Boot an iOS simulator (iOS 16+, e.g. `xcrun simctl boot "iPhone 16"`). 2. `fvm flutter devices` lists it; note its id. 3. `cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <simulator-id>`. | Build succeeds with the `dev` scheme; app installs as "Lumen Dev" (bundle `com.vaultvoice.vaultvoice.dev`, dev icon), launches without a crash to the Record screen, shows the DEBUG banner (dev flavor) and the dev-only "CallGuard debug" app-bar action. | iOS simulator | | | | |
| [FND-01/AC2] | 1. Create/boot an Android emulator from an arm64-v8a system image, API 26+ (e.g. `emulator -avd <avd>`). 2. `fvm flutter devices` lists it; note its id. 3. `cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <emulator-id>`. | Build succeeds for the `dev` flavor; app installs as "Lumen Dev" (id `com.vaultvoice.vaultvoice.dev`, dev icon), launches without a crash to the Record screen, shows the DEBUG banner (dev flavor) and the dev-only "CallGuard debug" app-bar action. | Android emulator | | | | |

## Notes / evidence
Fill Device (simulator/AVD model), OS, Result (`PASS`/`FAIL`), Date (`YYYY-MM-DD`) and Tester
only after actually running the row. Screenshots go under
`docs/test-plans/device/evidence/FND-01/`.

Host-side checks (no simulator/emulator on the authoring machine): the format and analyze
gates are covered by the automated `[FND-01/AC1]` tests in `tools/ci/tests/test_repo_standards.py`.
