# Device verification — QCP-01 Quick-capture decision

QCP-01 is a decision task (no app code). These rows list every claim in
`docs/adr/ADR-QCP-01-quick-capture.md` that could not be verified from official documentation or the
installed SDK without hardware (marked **[U]** there). Nothing here was run. They are executed during
QCP-02 (iOS) / QCP-03 (Android) and must be answered before the ADR can move from Proposed to Accepted
for any start-now option. Fill Device/OS/Result/Date/Tester only after running.

Acceptance criterion: [QCP-01/AC6] — items that cannot be verified without hardware are listed here.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [QCP-01/AC6] D1 | Build the Runner with a widget + control extension at deployment target iOS 16.0 using Xcode 27 (SDK 27.0), Control code behind `@available(iOS 18.0, *)`. Install on an iOS 16/17 device and an iOS 18+ device. | Builds and installs; iOS 16/17: Home and Lock Screen widgets available, no control offered; iOS 18+: control in Control Center / Lock Screen gallery. | iPhone on iOS 16/17 and iPhone on iOS 18+ | iOS 16.x/17.x and 18+ | | | |
| [QCP-01/AC6] D2 | Settings > Action Button: list which iPhone models show the **Controls** option and pick the VaultVoice control; note the lowest iOS offering it. | Model list and lowest iOS recorded (Apple documents only "supported models"). Control press opens the app on the Record screen. | Every Action-button iPhone in the lab (QA-05 matrix) | 18+ | | | |
| [QCP-01/AC6] D3 | With the Record control assigned to the Action button, then try to run it from: Shortcuts app (search for VaultVoice actions), Spotlight, Siri ("Record in VaultVoice"), a Shortcuts personal automation (time of day), Back Tap, Focus filter. | No VaultVoice action appears in Shortcuts/Spotlight/Siri; no automation can open or start the recorder. Record whether the Action-button *Shortcut* option can list anything from VaultVoice (expected: nothing). | iPhone with Action button | 18+ | | | |
| [QCP-01/AC6] D4 | Trigger the control from the Lock Screen with the app killed, then with the app backgrounded, while no foreground session exists. Watch for the orange microphone dot and Console logs. | The microphone never opens before the in-app Record tap; `RecordingController` reports `notForeground` if anything tried. | iPhone | 18+ | | | |
| [QCP-01/AC6] D5 | With a free personal team (no paid membership) try: add an App Extension target, add App Groups, build, install on a device. | Result recorded: whether a widget/control extension and App Groups can be signed with a Personal Team (Apple's page lists only the 10 App IDs / 3 devices / 7-day limits). The recommended design needs no App Group. | Any iPhone | 16+ | | | |
| [QCP-01/AC6] D6 | Android Quick Settings tile with `startActivityAndCollapse(PendingIntent)` → `MainActivity` on Android 14, 15 and 16: unlocked, then locked with the keyguard. | Activity opens in the foreground on the Record screen; behaviour on a locked device recorded; no `ActivityTaskManager` background-launch block in logcat (filter logcat for "background activity"). | Pixel (API 34, 35, 36) | Android 14+ | | | |
| [QCP-01/AC6] D7 | Only for the Option C upgrade: from a tile tap and from a widget tap, try creating the microphone foreground service (AUD-05) immediately, before the activity is visible. | Expected from docs: widget interaction is an FGS exemption; tile is not listed — record whether `ForegroundServiceStartNotAllowedException`/`SecurityException` appears. Not needed for Option A (the activity is visible before the in-app Record tap). | Pixel (API 34, 35, 36) | Android 14+ | | | |
| [QCP-01/AC6] D8 | Control with `requiresLocalDeviceAuthentication`: tap it on the Lock Screen of a locked iPhone. | System asks to unlock first, then the app opens on the Record screen; no screen content is shown while locked. | iPhone | 18+ | | | |
| [QCP-01/AC6] D9 | Android: from `adb shell` and a second app, try to start the Record trampoline activity / send the widget and tile PendingIntent extras (`adb shell am start …`, Tasker-style intent). | A non-exported trampoline cannot be started by another app; the exported `MainActivity` can only be navigated to the Record screen (no start). Record whether `TileService.onClick` can fire without a user tap. | Pixel | Android 14+ | | | |
| [QCP-01/AC6] D10 | Cold-start timing of the hand-off: force-stop the app, tap each entry point, measure from tap to Record screen with a screen recording (60 fps), 10 runs on the oldest supported iPhone (iOS 16) / widget only, and the oldest Android (API 26). | Median and max recorded; max < 10 s (the ADR's expiry) or the expiry value is revised. | Oldest iPhone + oldest Android in the matrix | iOS 16+ / API 26+ | | | |
| [QCP-01/AC6] D11 | Control spike: implement the Record control on iOS 18–25 with an app-target intent using `openAppWhenRun` and on iOS 26+ with `supportedModes = .foreground(.immediate)`. | Both open the app on the Record screen with the device locked/unlocked; no error from "intent runs in an extension" (Apple: `openAppWhenRun` errors in an extension). | iPhone iOS 18–25 and iOS 26+ | 18+ | | | |
| [QCP-01/AC6] D12 | Stale/replayed request: tap an entry point, kill the app before it opens, wait > 10 s, launch from the icon; repeat with a replayed URL/intent. | App opens normally; Record screen not forced; microphone not opened; log has an event name + reason only. | iPhone + Android phone | iOS 16+ / API 26+ | | | |

## Notes / evidence
Evidence under `docs/test-plans/device/evidence/QCP-01/`.


> **2026-10-17 human decision:** Action Button support is deferred and no entry point starts recording (navigate-only). Rows covering the Action Button (D2, D3) and start-now behaviour (D7) are **deferred**, kept for a later task; they do not block QCP-01.
