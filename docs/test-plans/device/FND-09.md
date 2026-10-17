# Device verification — FND-09 macOS Desktop Target

Host run on an Apple Silicon Mac. The Xcode license must already be accepted.
Do not fill Result until the row has actually been run.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-09/AC1] | 1. On an Apple Silicon Mac with Xcode installed and the license accepted, `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. 2. `cd app`. 3. `fvm flutter build macos --flavor dev -t lib/main_dev.dart`. 4. `file build/macos/Build/Products/Debug-dev/vaultvoice.app/Contents/MacOS/vaultvoice`. 5. `plutil -p build/macos/Build/Products/Debug-dev/vaultvoice.app/Contents/Info.plist`. | The build exits 0. `file` reports an arm64 Mach-O executable. Info.plist `CFBundleIdentifier` is `com.vaultvoice.vaultvoice.dev` and `LSMinimumSystemVersion` is `13.0`. | Mac arm64 | macOS 13+ | | | |
| [FND-09/AC2] | 1. On an Apple Silicon Mac, `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. 2. `cd app`. 3. `fvm flutter run -d macos --flavor dev -t lib/main_dev.dart`. 4. Look at the window title bar and the Record screen. 5. Try the close, minimize, and zoom buttons, and try to shrink the window. | An arm64 window opens on the Record screen. The DEBUG banner is visible. The dev-only CallGuard debug action is in the app bar. The title is Lumen Dev (bundle `com.vaultvoice.vaultvoice.dev`). Close, minimize, and zoom work with the pointer. The window content cannot shrink below 800×600. | Mac arm64 | macOS 13+ | | | |
| [FND-09/AC2] | 1. Run the dev app (`fvm flutter run -d macos --flavor dev -t lib/main_dev.dart`) with a fresh state. 2. Onboarding "What Lumen will ask for": click **Open settings**, then **Select folder**. 3. "AI models for this device": read the storage line. 4. "Where should notes go": click **Choose folder**, pick a folder in Documents, finish onboarding. 5. Record tab. | **Open settings** opens System Settings › Privacy & Security › Microphone. **Select folder** opens the macOS folder panel. The storage line shows real free space (no "not enough space" on a Mac with plenty free). **Choose folder** returns the chosen folder (no "couldn't be used"); after a relaunch the folder is still usable (bookmark). The Record screen shows no "Recording unavailable" / "call state could not be checked". | Mac arm64 | macOS 13+ | ⏳ | | |
| [FND-09/AC2] | Export a note to the chosen folder, quit the app, relaunch, export again. Then import a `.m4a` / `.wav` from the Library import action. | Both notes are written into the chosen folder without a new picker. The import decodes (an `.ogg` shows "not supported"). | Mac arm64 | macOS 13+ | ⏳ | | |

## Notes / evidence
Leave Result, Date, and Tester blank until this row is run on the Mac. Do not
record a PASS from a project inspection or a failed build. Screenshots go under
`docs/test-plans/device/evidence/FND-09/`.

`fvm flutter build macos --flavor dev -t lib/main_dev.dart` is the AC1 build.
The host-side project check is `[FND-09/AC1]` in
`app/test/unit/macos_desktop_target_test.dart` (deployment target 13.0, arm64
only, dev bundle id and display name). It does not replace a built `.app`.

Host channels (`fix/macos-host`): `app/macos/Runner` answers `app_settings`,
`storage_info`, `model_download` (device facts only), `call_guard` (`isInCall`
= false, no call API: ADR-SEC-09), `recording_indicator` (acknowledge; macOS
shows the menu-bar mic indicator), `device_auth` (LocalAuthentication),
`privacy_screen` (no-op), `secure_storage` (Keychain), and the Bookmark, audio
import and purchase Pigeon APIs (purchase answers `unavailable`). The
`processing` channel is not registered on macOS: Dart uses
`NoBackgroundProcessingPlatform` there. Automated check on a Mac:
`cd app && fvm flutter test integration_test/macos_host_channels_test.dart -d macos --flavor dev`
(passed on the developer Mac; it does not open Settings, Touch ID or the panel).
