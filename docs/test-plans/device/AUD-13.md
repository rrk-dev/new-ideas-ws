# Device verification — AUD-13 iOS Live Activity

AUD-13 adds a recording Live Activity (Lock Screen + Dynamic Island) to the `LumenWidgets` extension. It
shows state (Recording / Paused) and a timer only, has no buttons, intents or push token, and only opens
the Record screen on tap. Nothing below has been run: the agent had no physical iPhone. Fill
Device/OS/Result/Date/Tester only after running. Evidence goes under
`docs/test-plans/device/evidence/AUD-13/`.

Design facts these rows check:

- Started/updated/ended from the `show`/`hide` calls of `vaultvoice/recording_indicator`, which follow
  the in-app Record tap (`RecordingIndicatorBinding`). iOS 16.2+ only (`#available`); iOS 16.0/16.1 get
  no Activity and rely on the OS microphone indicator (ADR-SEC-09 §5, Amendment 4).
- The payload is `{recording: Bool, timerStart: Date?}`; the extension reads no database or shared
  container.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-13/AC1] D1 | Tap Record in the app, lock the phone, then pause, resume and stop from the app. | Lock Screen Activity shows "Recording" and a running timer; "Paused" without a timer while paused; timer restarts from the correct elapsed time on resume; the Activity disappears right after stop. | iPhone 15 (Dynamic Island) | 27.0.1 | PARTIAL: Lock Screen Activity shows while recording (owner confirmed). Pause, resume, stop and timer not yet confirmed | 2026-10-18 | rajesred |
| [AUD-13/AC1] D2 | Same on an iPhone with Dynamic Island; check compact, minimal and expanded presentations. | Mic/pause symbol and timer in each presentation; no clipped or empty view. | iPhone 14 Pro or newer | 16.2+ | | | |
| [AUD-13/AC1] D3 | Start a recording, then force-quit the app, relaunch, and look at Settings > Lumen and the Lock Screen. | The Activity is ended on the next `hide`/launch path; record whether a stale Activity can remain after a crash and for how long (the system ends it after its own limit). | iPhone | 16.2+ | | | |
| [AUD-13/AC2] D4 | Tap the Lock Screen Activity and the Dynamic Island with the app killed and with no recording running. | App opens on the Record screen (navigate-only); the microphone does not open; no recording starts, resumes or stops. | iPhone | 16.2+ | | | |
| [AUD-13/AC2] D5 | While recording, receive a phone call and a FaceTime call. | Capture stops per AUD-04; Activity switches to Paused (never resumes by itself) and ends when the recording ends; the call is not recorded. | iPhone | 16.2+ | | | |
| [AUD-13/AC3] D6 | Turn Live Activities off in Settings > Lumen; start a recording. | Recording works; no Activity; no error shown; OS microphone indicator still visible. | iPhone | 16.2+ | | | |
| [AUD-13/AC3] D7 | Record 30 min with the screen locked (8 h is out of scope). | Timer stays correct without app updates (the timer is a system-rendered `Text(date, style: .timer)`); note whether the system ends the Activity at its limit (**Unverified** that an Activity outlives 8 h). | iPhone | 16.2+ | | | |
| [AUD-13/AC3] D8 | Install on an iOS 16.0/16.1 device or simulator. | App builds, installs and records; no Activity and no crash. | iPhone/simulator on 16.0–16.1 | 16.0–16.1 | | | |
| [AUD-13/AC3] D9 | Free Personal Team: sign and install the Runner + `LumenWidgets` with `NSSupportsLiveActivities`. | Result recorded: whether a Personal Team can sign the extension and use Live Activities (**Unverified**; no App Group or push capability is used). | iPhone 15 | 27.0.1 | PASS: Runner + LumenWidgets (NSSupportsLiveActivities) signed with a free Personal Team and installed, once the App Group and Share extension were removed for the local build. Live Activity appeared. App Groups cannot be signed on a Personal Team (affects AUD-14 and the Share extension) | 2026-10-18 | rajesred |
| [AUD-13/AC4] D10 | Network monitor (Instruments / proxy) during a recording with the Activity visible. | No network request from Lumen or `LumenWidgets`; no push-token registration. | iPhone | 16.2+ | | | |
