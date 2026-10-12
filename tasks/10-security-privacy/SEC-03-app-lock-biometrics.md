# SEC-03 — App Lock (Biometric / Passcode)

**Workstream:** Security & Privacy | **Phase:** 4 | **Size:** S | **Depends on:** SEC-01 | **Source:** Gap (regulated-user expectation)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-testing

## Goal
Optional lock protecting in-app recordings and transcripts.

## Scope
- [ ] `local_auth` Face ID / Touch ID / fingerprint with device-passcode fallback.
- [ ] Lock on launch and after N minutes in background; blur app switcher snapshot.
- [ ] Recording can still be started by an explicit user tap on the widget/tile while the app lock is engaged (content stays hidden); SEC-07/SEC-09 rules (consent step, call guard, visible indicator) still apply.
- [ ] Enforceable via MDM (LIC-04).

## Acceptance Criteria
- App switcher shows no content when lock is enabled; lock timeout respected.
