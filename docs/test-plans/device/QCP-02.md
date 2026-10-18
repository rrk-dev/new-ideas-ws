# Device verification — QCP-02 iOS quick capture

QCP-02 adds a Home/Lock Screen widget and an iOS 18 Lock Screen / Control Center control that only
open Lumen on the Record screen (navigate-only, `docs/adr/ADR-QCP-01-quick-capture.md`). Nothing
below has been run yet: the agent had no physical iPhone. Fill Device/OS/Result/Date/Tester only
after running. Evidence goes under `docs/test-plans/device/evidence/QCP-02/`.

Design facts that these rows check:

- The widget opens the app with the `lumen://record?entry=widget` URL; the control runs an app-target
  App Intent (`openAppWhenRun`, not discoverable). Both store a memory-only, single-use request
  (10 s expiry) that Dart reads through the Pigeon `consumeRequest()` and turns into navigation.
- No App Group is used. Apple's "Supported capabilities (iOS)" table lists App Groups for the free
  Apple Developer account too, but it does not say whether a free Personal Team can sign an app
  **extension**. That is Unverified (row D5).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [QCP-02/AC1] | Add the Lumen widget (Home Screen small, Lock Screen circular/rectangular) and, on iOS 18+, the Lumen control. Tap each; then tap Record in the app and stop after 10 s. Open the file in the Library. | The app opens on the Record screen and the microphone indicator is off; recording starts only after the in-app tap and yields a valid 16 kHz mono WAV in the Library. | iPhone iOS 16/17 (widget) and iPhone iOS 18+ (widget + control) | 16+ | ⏳ | | |
| [QCP-02/AC4] | Place a call to the device and let it ring (then repeat during an active call). After a widget/control open, tap Record in the app. | Recording refuses (CallGuard); the app never starts capture on its own. | iPhone | 16+ | ⏳ | | |
| [QCP-02/AC5] | Inspect the Home Screen, Lock Screen, Control Center, widget gallery and StandBy surfaces after recording and processing several notes. | Only the static "Record" / "Lumen" text and the microphone symbol appear; no title, transcript, duration or count. | iPhone | 16+ | ⏳ | | |
| [QCP-02/AC6] D1 | Build and install with Xcode 27 (SDK 27.0) at deployment target 16.0, control code behind `@available(iOS 18.0, *)`. | Builds and installs; iOS 16/17 offer no control, iOS 18+ lists it. | iPhone iOS 16/17 and 18+ | 16+ | ⏳ | | |
| [QCP-02/AC6] D5 | With a free Personal Team, build and install Runner with the embedded `LumenWidgets` extension. | Result recorded: can the extension be signed and installed. The design needs no App Group, so none is requested. | Any iPhone | 16+ | ⏳ | | |
| [QCP-02/AC6] D8 | Tap the control on the Lock Screen of a locked iPhone. | System asks to unlock, then the app opens on Record; no content shown while locked. (Lumen does not set `requiresLocalDeviceAuthentication` yet; record the observed system behaviour.) | iPhone | 18+ | ⏳ | | |
| [QCP-02/AC6] D10 | Force-quit the app, tap the widget 10 times, time tap to Record screen with a 60 fps screen recording. | Median and max recorded; max below the 10 s expiry, otherwise the expiry is revised. | Oldest supported iPhone | 16+ | ⏳ | | |
| [QCP-02/AC6] D11 | Tap the control with the app killed and with the app in the background, locked and unlocked, on iOS 18–25 and iOS 26+. | App opens on Record each time. Apple deprecates `openAppWhenRun` in iOS 26 in favour of `supportedModes`; record whether it still works there. | iPhone iOS 18–25 and 26+ | 18+ | ⏳ | | |
| [QCP-02/AC6] D12 | Tap the widget, force-quit before it opens, wait over 10 s, launch from the icon; repeat the `lumen://record?entry=widget` URL from Safari. | App opens normally, Record is not forced, the microphone stays off, log has event name and reason only. | iPhone | 16+ | ⏳ | | |

## Not run

- The native XCTest `RunnerTests/QuickCaptureStoreTests.swift` compiles, but `xcodebuild test` on the
  iPhone 17 Pro simulator failed with "Simulator device failed to install the application". The
  store logic was checked once with a standalone `swiftc` harness. Follow-up: run the XCTest on a
  working simulator or device.
- Action Button, Shortcuts and Siri rows (QCP-01 D2, D3) are deferred by the product decision.
