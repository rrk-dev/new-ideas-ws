# Device verification — FND-09 macOS Desktop Target

Host run on an Apple Silicon Mac. The Xcode license must already be accepted.
Do not fill Result until the row has actually been run.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-09/AC2] | 1. On an Apple Silicon Mac, `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. 2. `cd app`. 3. `fvm flutter run -d macos --flavor dev -t lib/main_dev.dart`. 4. Look at the window title bar and the Record screen. 5. Try the close, minimize, and zoom buttons, and try to shrink the window. | An arm64 window opens on the Record screen. The DEBUG banner is visible. The dev-only CallGuard debug action is in the app bar. The title is VaultVoice Dev (bundle `com.vaultvoice.vaultvoice.dev`). Close, minimize, and zoom work with the pointer. The window content cannot shrink below 800×600. | Mac arm64 | macOS 13+ | | | |

## Notes / evidence
Leave Result, Date, and Tester blank until this row is run on the Mac. Do not
record a PASS from a project inspection or a failed build. Screenshots go under
`docs/test-plans/device/evidence/FND-09/`.

`fvm flutter build macos --flavor dev -t lib/main_dev.dart` is the AC1 build.
The host-side project check is `[FND-09/AC1]` in
`app/test/unit/macos_desktop_target_test.dart` (deployment target 13.0, arm64
only, dev bundle id and display name). It does not replace a built `.app`.
