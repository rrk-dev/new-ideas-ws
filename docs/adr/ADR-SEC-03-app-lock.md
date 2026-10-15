# ADR-SEC-03 — App lock: platform authentication APIs instead of `local_auth`

- **Status:** Proposed (host-verified; device runs pending — `docs/test-plans/device/SEC-03.md`)
- **Date:** 2026-10-14
- **Task:** SEC-03
- **Deciders:** Claude Code (implementer); pending independent verifier + human
- **Supersedes:** —

## Context
SEC-03 asks for an optional app lock (Face ID / Touch ID / fingerprint with device-passcode
fallback), lock on launch and after N minutes in the background, a content-free app-switcher
snapshot, and recording still startable by a tap while locked. The task names `local_auth`.

`local_auth` 3.0.2 (federated `local_auth_android` 2.3.0) **requires the Android activity to be a
`FragmentActivity`** (`FlutterFragmentActivity`, plus AppCompat themes for API ≤ 27, README →
"Activity Changes" / "Android theme"). Our `MainActivity` is a `FlutterActivity` whose
`provideFlutterEngine` / `shouldDestroyEngineWithHost` overrides keep the Flutter engine alive
while the AUD-05 microphone foreground service records after the activity is swiped away. In
`FlutterFragmentActivity` (Flutter 3.47.7 `FlutterFragmentActivity.java`)
`shouldDestroyEngineWithHost()` is read once, when the `FlutterFragment` is built in `onCreate`,
instead of when the host is destroyed — the AUD-05 decision ("is a recording running *now*?")
could no longer be made. Changing the activity base class would put background recording at risk
for a feature that needs ~150 lines of platform code.

## Options
1. **`local_auth` 3.0.2** + switch `MainActivity` to `FlutterFragmentActivity` + AppCompat
   `LaunchTheme`/`NormalTheme` + `androidx.appcompat` dependency.
2. **Own `AppLockPlugin`** on the platform APIs: iOS `LAContext.evaluatePolicy(
   .deviceOwnerAuthentication)`; Android framework `android.hardware.biometrics.BiometricPrompt`
   (API 28+, works with any `Activity`) with `BIOMETRIC_WEAK | DEVICE_CREDENTIAL` (API 30+) /
   `setDeviceCredentialAllowed(true)` (28–29) and `KeyguardManager.
   createConfirmDeviceCredentialIntent` (26–27).

## Criteria (weights fixed before evaluating)
| Criterion | Weight |
|---|---|
| No regression of AUD-05 background recording / retained engine | 35% |
| Correct auth semantics (biometric + passcode fallback, API 26+) | 25% |
| Integration effort / shared-file churn (MainActivity, themes, Gradle) | 15% |
| Dependency surface (privacy audit, licenses, updates) | 15% |
| Testability on host | 10% |

## Evidence
- `local_auth_android` 2.3.0 README (pub cache) — FragmentActivity + AppCompat requirement;
  `build.gradle.kts` adds `androidx.biometric:biometric:1.1.0`, `androidx.fragment:1.8.9`.
- Flutter 3.47.7 engine source `FlutterFragmentActivity.java` — `shouldDestroyEngineWithHost()`
  returns the intent extra and is consumed when the fragment is created.
- Android SDK: `BiometricPrompt` (API 28), `setAllowedAuthenticators` (API 30),
  `KeyguardManager.isDeviceSecure` (API 23), `createConfirmDeviceCredentialIntent` (API 21,
  deprecated in 29 but functional — used only on 26–27).
- Host tests: `app/test/unit/app_lock/app_lock_test.dart`, `app/test/widget/app_lock_gate_test.dart`.
  No device available (⏳ rows).

| Criterion | Option 1 | Option 2 |
|---|---|---|
| AUD-05 safety (35) | 2 | 5 |
| Auth semantics (25) | 5 | 4 (three code paths) |
| Effort / churn (15) | 2 | 4 |
| Dependencies (15) | 3 | 5 |
| Testability (10) | 4 | 4 |
| **Total** | 3.10 | **4.50** |

## Decision
**Option 2.** `AppLockPlugin` (`app/ios/Runner/AppLockPlugin.swift`,
`app/android/.../security/AppLockPlugin.kt`) exposes `vaultvoice/device_auth`
(`authenticate → success | failed | unavailable`) and `vaultvoice/privacy_screen`
(`setEnabled`). Dart: `AppLockMachine` (pure state machine), `AppLock` notifier
(effective settings `security.app_lock` / `security.lock_timeout`, managed › user › default, so
LIC-04 MDM `force_app_lock` works through `ManagedSettings`), `AppLockGate` in `App.builder`.

- **Lock on launch**; starts covered until settings load (fail closed while loading; a settings
  error falls back to the default "off").
- **Re-lock** when the app returns after ≥ timeout in `hidden`/`paused` (`immediately`, 1, 5,
  15 min).
- **App switcher:** iOS adds an opaque cover to the scene's windows on
  `UIScene.willDeactivateNotification` (the notification twin of `sceneWillResignActive(_:)`;
  observing it keeps `FlutterSceneDelegate`'s lifecycle forwarding untouched) and removes it on
  `didActivateNotification`. Android sets `FLAG_SECURE` while the lock is enabled (blank recents
  thumbnail; screenshots blocked — accepted side effect).
- **Content hidden** under the lock: the app stays mounted (navigation, an ongoing recording)
  but is not painted, not hit-testable and excluded from semantics.
- **Recording while locked:** the lock screen's "Start recording" button calls the single
  `RecordingController.start(StartSource.inAppButton)` entry point — an explicit tap, CallGuard,
  visible indicator and every SEC-09 rule apply; only "Recording…" and Stop are shown. The
  home-screen widget / tile / iOS Control (AUD-08) open the app first and land on this screen.
- **PRODUCT-DECISION:** a device without passcode/biometrics cannot be locked
  (`unavailable` unlocks, with an explanation) — otherwise users would be locked out of their data.
- `USE_BIOMETRIC` (normal permission) added to the manifest; `NSFaceIDUsageDescription` to
  Info.plist. No new pub dependency.

## Consequences
- Positive: AUD-05 unchanged; no FragmentActivity/AppCompat migration; no new package to audit.
- Negative / risks: three Android code paths to verify on devices (API 26/27 confirm-credential,
  28–29, 30+); Kotlin/Swift compiled only by CI here. `FLAG_SECURE` also blocks user
  screenshots while the lock is on.
- Follow-ups: AUD-08 widget/tile/Control entry points should route to the lock screen's record
  action when locked; LIC-04 maps MDM `force_app_lock` → managed `security.app_lock = true`.
