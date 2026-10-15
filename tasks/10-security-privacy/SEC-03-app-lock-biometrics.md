# SEC-03 — App Lock (Biometric / Passcode)

**Workstream:** Security & Privacy | **Phase:** 4 | **Size:** S | **Depends on:** SEC-01 | **Source:** Gap (regulated-user expectation)
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-testing

## Goal
Optional lock protecting in-app recordings and transcripts.

## Scope
- [x] `local_auth` Face ID / Touch ID / fingerprint with device-passcode fallback. (Same capability via the platform APIs in our own `AppLockPlugin` — `local_auth` needs a FragmentActivity, which would break the AUD-05 retained engine; ADR-SEC-03.)
- [x] Lock on launch and after N minutes in background; blur app switcher snapshot.
- [x] Recording can still be started by an explicit user tap on the widget/tile while the app lock is engaged (content stays hidden); SEC-07/SEC-09 rules (consent step, call guard, visible indicator) still apply.
- [x] Enforceable via MDM (LIC-04): the lock reads the effective `security.app_lock` (managed › user), so LIC-04's `force_app_lock` → managed value enforces it (tested with a managed source).

## Acceptance Criteria
- App switcher shows no content when lock is enabled; lock timeout respected.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/SEC-03-app-lock (stacked on
  task/SEC-04-data-retention-secure-deletion → task/SEC-01-encryption-at-rest) · **Date:** 2026-10-14
- **Summary:** `app/lib/features/app_lock/` — `AppLockMachine` (lock on launch, re-lock after
  the `security.lock_timeout` in `hidden`/`paused`), `AppLock` notifier on the effective settings,
  `AppLockGate` in `App.builder` (content kept mounted but unpainted, not hit-testable, excluded
  from semantics; neutral cover while settings load), `LockScreen` with Unlock + "Start
  recording"/"Stop recording" through `RecordingController.start(StartSource.inAppButton)`.
  Native `AppLockPlugin` (iOS `LAContext .deviceOwnerAuthentication` + window cover on
  `UIScene.willDeactivateNotification`; Android platform `BiometricPrompt` /
  confirm-credential + `FLAG_SECURE`), `USE_BIOMETRIC`, `NSFaceIDUsageDescription`. Lock screen
  rows added to the APP-06 accessibility test; APP-04's processing test now provides a settings
  store (the gate waits for settings). Kotlin/Swift are compiled by the CI android/ios jobs.
- **Acceptance evidence:**
  - AC1: ⏳ test: [SEC-03/AC1]; device: docs/test-plans/device/SEC-03.md; artifact: docs/adr/ADR-SEC-03-app-lock.md
- **Decisions:** ADR-SEC-03-app-lock (Proposed). PRODUCT-DECISIONs: a device without
  passcode/biometrics cannot be locked (unlocks with an explanation); `FLAG_SECURE` also blocks
  screenshots while the lock is on; enabling the lock does not lock the current session.
- **Follow-ups:** AUD-08 widget/tile/Control entry points open the app onto the lock screen's
  record action while locked; LIC-04 maps `force_app_lock`.
