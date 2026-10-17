# QCP-02 — iOS quick capture: widget, Lock Screen control, Action Button intent

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** L | **Depends on:** QCP-01, AUD-04, AUD-08, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture)
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-background-execution, vv-privacy-security, vv-testing, vv-ci-release

## Goal
On iPhone, a user can start a recording with one deliberate tap from the Home Screen, Lock Screen, Control Center or Action Button, exactly as decided in ADR-QCP-01.

## Scope
- [ ] Add the native targets ADR-QCP-01 requires (widget/controls extension, App Group if needed). Existing bundle ids and signing stay unchanged (the repo currently has only the Runner and RunnerTests targets; any ShareExtension wiring is outside this task unless ADR-QCP-01 absorbs it); document targets and entitlements in `docs/ci.md`.
- [ ] Home Screen / Lock Screen widget: record action and static Lumen branding only.
- [ ] Control and an App Intent for the Action Button / Shortcuts behaving as ADR-QCP-01 decided, including its answer on invocation provenance (SEC-09 forbids automations).
- [ ] Hand-off to Flutter through a Pigeon API: single-use token with the ADR's expiry; Dart validates it, then, **only if ADR-QCP-01 chose start-now for that entry point**, runs the shared consent/setup flow (first-run acknowledgement, profile consent, microphone priming, `consent_confirmed_at` saved) and calls `RecordingController.start(StartSource.<value>)` once the app is foreground. A navigate-only entry point opens the Record screen and never calls `start`. Stale, replayed or missing tokens are ignored and logged without content.
- [ ] Add the Action Button `StartSource` value per the approved SEC-09 amendment and update the pinned allowlist test. macOS behaviour is unchanged unless the ADR says otherwise.
- [ ] Visible indicator and CallGuard match an in-app start (refuse during a call, never auto-resume). If ADR-QCP-01 requires a Live Activity, build it here.
- [ ] Keep `tools/ci/check_recording_policy.sh` and `check_egress.sh` passing; no permission, background mode or network host beyond what the ADR approves.
- [ ] Tests: Dart unit tests for token validation and source mapping; native unit tests where the toolchain allows; device rows for the rest.

## Acceptance Criteria
- A widget / control / Action Button press on a physical iPhone starts (or opens ready to start, per the ADR) a recording, and the resulting recording is a valid 16 kHz mono WAV in the Library (device row `docs/test-plans/device/QCP-02.md`).
- An expired token, a reused token and an app launch with no token never start recording (automated Dart tests, `[QCP-02/ACn]`).
- `allowedStartSources` equals the set approved by the ADR; a pinned test fails if a value is added without it (automated).
- While a phone call is ringing or active, none of the entry points records (device row; same CallGuard path as AUD-04).
- With missing acknowledgement, required multi-person consent or cancelled microphone priming, no quick-capture path touches the microphone, and `consent_confirmed_at` is stored when consent is given (automated, `[QCP-02/ACn]`).
- No widget, control or Lock Screen surface shows recording-derived text (automated test of the data the extension reads, plus device row).
- `check_recording_policy.sh`, `check_egress.sh`, `flutter analyze` and the targeted tests pass; the built Info.plist/entitlements add no permission, background mode or host beyond the ADR.

## Notes
- Controls and the Action Button need specific iOS versions and hardware (verified in QCP-01); on older iOS the new surfaces are simply absent and the app still builds for iOS 16+.
- Shipping extensions/App Groups may need a paid Apple Developer team; QCP-01 records what a free personal team supports for on-device testing.
