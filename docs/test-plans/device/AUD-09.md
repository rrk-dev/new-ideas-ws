# Device verification — AUD-09 macOS Microphone Capture

The capture path has run against fakes (`app/test/unit/recording/macos_microphone_test.dart`).
A real microphone grant was not run: the macOS runner is FND-09's (`app/macos` is not
edited here) and this session did not accept the Xcode license. Leave Result, Date, and
Tester blank until someone runs the steps. Do not mark PASS without that run.

Setup: `cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer fvm flutter run -d macos --flavor dev -t lib/main_dev.dart`.
Open the Record tab → **Recording debug** → Start. Chunks are under the app-support
`vv/audio/<recording_id>/chunk_NNNN.wav`. Check with `afinfo` or `soxi`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-09/AC2] | 1. Launch the dev macOS app. 2. Grant the microphone when macOS asks. The prompt must say the app records a note, not a call. 3. Tap Start on Recording debug (the Record button). Speak a few seconds. Stop. 4. Inspect `chunk_0000.wav`. | One WAV. `afinfo` / `soxi` shows 16000 Hz, 1 channel, 16-bit PCM. The menu-bar microphone indicator is visible only while recording. Unplugging the mic pauses the recording and it stays paused until Resume is tapped. | This Mac | macOS 13+ arm64 | | | |

## Notes / evidence
Automated counterparts: `[AUD-09/AC1]` refuses every start that is not the Record button and checks the 16 kHz mono header; `[AUD-09/AC3]` checks `packages/vv_native/macos/Info.plist` and the entitlements. FND-09 still has to merge those into `app/macos/Runner`.
