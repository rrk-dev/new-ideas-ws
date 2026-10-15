# Device verification — AUD-09 macOS Microphone Capture

The capture path has run against fakes (`app/test/unit/recording/macos_microphone_test.dart`)
and the macOS dev app builds. A real microphone grant needs a human at a Mac. Rows start ⏳;
a tester fills Result, Date, and Tester. Do not mark PASS without a real run.

Setup: `cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer fvm flutter run -d macos --flavor dev -t lib/main_dev.dart`.
Open the Record tab → **Recording debug** → Start. Chunks are under the app-support
`vv/audio/<recording_id>/chunk_NNNN.wav`. Check with `afinfo` or `soxi`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-09/AC2] | 1. Launch the dev macOS app. 2. Grant the microphone when macOS asks. The prompt must say the app records a note, not a call. 3. Tap Start on Recording debug (the Record button). Speak a few seconds. Stop. 4. Inspect `chunk_0000.wav`. | One WAV. `afinfo` / `soxi` shows 16000 Hz, 1 channel, 16-bit PCM. The menu-bar microphone indicator is visible only while recording. Unplugging the mic pauses the recording and it stays paused until Resume is tapped. | This Mac | macOS 13+ arm64 | ⏳ | | |
| [AUD-09/AC2] | Deny the microphone in System Settings › Privacy & Security › Microphone, then tap Start. | A permission failure is shown; no chunk is written; the menu-bar microphone indicator never appears. Granting later does not start a recording by itself. | This Mac | macOS 13+ arm64 | ⏳ | | |
| [AUD-09/AC1] | Relaunch the app with the microphone already granted. Wait 30 s. | No recording starts and no microphone indicator shows until Start is clicked. | This Mac | macOS 13+ arm64 | ⏳ | | |
| [AUD-09/AC2] | While recording, unplug the USB / disconnect the Bluetooth headset that is the input. | Recording pauses (interruption marker). It stays paused after replugging until Resume is tapped. | This Mac + headset | macOS 13+ arm64 | ⏳ | | |
| [SEC-09/AC2] | Start a FaceTime call, then record a note with the Record button. Also repeat with a call handed off via Continuity from an iPhone. | The note captures the microphone only. The app shows no call-audio source, and no other app's audio (the remote caller) appears in the WAV. Legal sign-off for call handling stays with SEC-09. | This Mac + iPhone | macOS 13+ arm64 | ⏳ | | |

## Notes / evidence
Automated counterparts: `[AUD-09/AC1]` refuses every start that is not the Record button and checks the 16 kHz mono header; `[AUD-09/AC3]` checks `packages/vv_native/macos/Info.plist` and the entitlements. `tools/ci/check_recording_policy.py` scans `app/macos` and `packages/*/macos` (`[AUD-09/AC3]` in `tools/ci/tests/test_recording_policy.py`).
