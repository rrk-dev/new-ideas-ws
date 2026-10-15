# Device verification — SEC-03 App Lock (Biometric / Passcode)

Design: `docs/adr/ADR-SEC-03-app-lock.md`. Host evidence: `[SEC-03/AC1]` tests in
`app/test/unit/app_lock/app_lock_test.dart` and `app/test/widget/app_lock_gate_test.dart`.
Setup for every row: a recording with a recognisable title exists; Settings → Privacy → App lock
**on**, "Lock after" as stated.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-03/AC1] | iOS: 1. Open the Library. 2. Swipe up to the app switcher (and also press Home, then open the switcher). | The VaultVoice card shows the opaque lock cover (lock symbol), no titles/transcripts. After returning, the cover is gone. | iPhone with Face ID (e.g. iPhone 13) | iOS 17/18 | ⏳ | | |
| [SEC-03/AC1] | Android: same as above via Recents; also try a screenshot inside the app. | Recents thumbnail is blank; screenshot is blocked ("can't take screenshot due to security policy"). With the lock **off**, thumbnail and screenshots work again. | Pixel 7 | Android 14 | ⏳ | | |
| [SEC-03/AC1] | Lock timeout: set "Lock after 1 minute". Unlock, background the app for 50 s, return; background again for 70 s, return. Repeat with "Immediately". | 50 s → no prompt; 70 s → lock screen; "Immediately" → lock screen after every return. Cold start always shows the lock screen. | iPhone 13 + Pixel 7 | iOS 17/18, Android 14 | ⏳ | | |
| [SEC-03/AC1] | Authentication paths: Face ID / Touch ID / fingerprint success; cancel; fall back to device passcode/PIN. Android API 26–27 device: confirm-credential screen; API 28–29: BiometricPrompt with "Use PIN". | Success unlocks; cancel keeps the lock; passcode fallback unlocks on every OS level. | iPhone SE (Touch ID), Pixel 7, Android 8.1 device (e.g. Nokia 6.1), Android 10 device | iOS 17, Android 14/10/8.1 | ⏳ | | |
| [SEC-03/AC1] | Device without passcode: remove the device passcode, enable App lock, relaunch. | Lock screen explains that the device has no passcode; tapping Unlock opens the app (cannot lock). | any | any | ⏳ | | |
| [SEC-03/AC1] | Recording while locked: lock the app, tap "Start recording" on the lock screen, speak 20 s, tap "Stop recording"; also trigger an incoming call while recording. | Recording starts only on the tap, OS mic indicator / recording notification visible, no library content shown; a call stops capture (SEC-09); the new recording appears in the Library only after unlocking. | iPhone 13 + Pixel 7 | iOS 17/18, Android 14 | ⏳ | | |

## Notes / evidence
Screen recordings under `docs/test-plans/device/evidence/SEC-03/`.
