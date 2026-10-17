# QCP-01 — Quick-capture decision: widget, Lock Screen control, Action Button, Android tile

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** S | **Depends on:** SEC-09, AUD-04, AUD-05, AUD-08, AUD-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture)
**Status:** review
**Skills:** vv-task-workflow, vv-decision-records, vv-audio-capture, vv-privacy-security, vv-flutter-architecture, vv-background-execution

## Goal
Decide, from verified platform facts, how a user starts a recording in one tap from outside the app (iOS widget / Lock Screen control / Action Button, Android widget / Quick Settings tile) without breaking SEC-09.

## Scope
- [x] Verify against official Apple and Android documentation and the installed SDKs (record the Xcode and Android SDK versions in the ADR; do not rely on memory):
  - iOS: WidgetKit home/Lock Screen widgets, App Intents, Control Center / Lock Screen controls (minimum iOS version; the app's iOS 16+ floor must still build), which iPhone models have an Action Button and how it runs an App Intent or Shortcut, whether an intent can open the microphone without the app in the foreground, App Group needs, and what a free personal signing team can and cannot sign for on-device testing.
  - Android: widget options (Glance vs RemoteViews), `TileService`, launcher app shortcuts, and the Android 14+ restrictions on starting a `microphone` foreground service from a background context (AUD-05 already uses an FGS of type microphone).
- [x] **Reconcile with the existing SEC-09 ADR §4**, which says widgets/Controls open the app and (per the AUD-08 follow-up) only *navigate* to the Record screen, the start staying an in-app tap, and `RecordingController` refuses unless the app is `resumed`. Decide per entry point: keep navigate-only, or start immediately after the app is foreground via a validated token. Record the one-tap vs two-tap trade-off. Any change to the SEC-09 ADR is written as an explicit amendment for human approval.
- [x] Define the hand-off from extension/tile to app as a single-use request with a short expiry (record the value) so a later app launch can never auto-start recording (SEC-09 forbids start-at-launch).
- [x] Map each entry point to `StartSource`. `homeScreenWidget`, `androidQuickSettingsTile` and `iosControl` already exist; the **Action Button / App Intent has no value yet** — propose the amendment (new value + pinned allowlist test) and state why a direct press is an explicit user start while Shortcuts *automations* stay forbidden.
- [x] macOS: `macosAllowedStartSources` allows only `inAppButton` (AUD-09). State whether macOS stays in-app-only (default) or propose an amendment; do not implement it.
- [x] Decide what any widget/control may display: record action and static text only; no titles, transcript text, summaries or note counts on Lock Screen or home-screen surfaces.
- [x] Decide the visible-indicator story per entry point (OS mic indicator, Android ongoing notification). Check whether an iOS Live Activity exists in the code today (none does; it is only a proposed follow-up, AUD-10 in AUD-04, which collides with the other AUD-10 proposal in AUD-06) and whether SEC-09's "Live Activity where supported" requires it before QCP-02 ships.
- [x] **Supersede the earlier proposals:** AUD-11 (quick-start entry points, proposed in AUD-08), AUD-10 (Live Activity, AUD-04) and the share-target wiring proposed in AUD-06 are not filed tasks. State in the ADR which of them QCP-02/QCP-03 absorb (quick start = QCP-02/03) and which stay separate, and note that the repo has no wired `ShareExtension` Xcode target yet (only Runner and RunnerTests).
- [x] **Invocation provenance:** decide whether an App Intent / Control / Action Button invocation can be shown to come from a physical user press (Apple documents that a non-discoverable intent is not available to system features, so the AUD-08 "undiscoverable intent" idea must be re-checked against the Action Button). If provenance cannot be established, the ADR must require an in-app start tap for that entry point rather than claim automations are excluded because a token is fresh.
- [x] **Consent and setup parity:** first-run acknowledgement, profile consent (SEC-07), microphone priming and setup persistence live in the Record screen flow (`recording_screen.dart`), not in `RecordingController.start`. The ADR states how each quick-capture path reuses them (shared flow) before any microphone access.
- [x] Write `docs/adr/ADR-QCP-01-quick-capture.md` (Proposed) and `docs/test-plans/device/QCP-01.md` listing what could not be verified without a device.

## Acceptance Criteria
- `docs/adr/ADR-QCP-01-quick-capture.md` exists with options, weighted criteria and the official documentation pages and SDK versions it was verified against.
- For each of {iOS widget, iOS Lock Screen control, iOS Action Button, Android widget, Android tile, macOS} the ADR states minimum OS/hardware, start-now vs navigate-only, the `StartSource` value, and the visible indicator.
- The ADR states, per entry point, how invocation provenance and consent/setup parity are satisfied, or requires an in-app tap.
- The ADR defines the single-use hand-off request (fields, expiry, storage) and shows how it prevents a start on app launch.
- The ADR contains exact SEC-09 ADR amendment text for the Action Button source and for any start-now decision, and states that no call-related permission, audio source or background mode is needed.
- Items that cannot be verified without hardware are listed as rows in `docs/test-plans/device/QCP-01.md`.

## Notes
- No Apple Watch app. No automations. Microphone only (SEC-09).
- QCP-02 (iOS) and QCP-03 (Android) must not start until a human marks this ADR Accepted.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/QCP-01-quick-capture-decision · **Date:** 2026-10-17
- **Summary:** Decision ADR (Proposed) with options, weighted criteria and cited Apple/Android documentation plus Xcode 27.0 (27A266a) / Android targetSdk 36 versions. Recommends navigate-only for all entry points (two taps); iOS invocation provenance is not establishable from documentation. Defines the 10 s single-use, memory-only hand-off request, shared consent/setup parity, static-only widget content, StartSource mapping, SEC-09 amendment texts and the fate of AUD-10/AUD-11. Device rows for everything unverified.
- **Acceptance evidence:**
  - AC1: ✅ artifact: docs/adr/ADR-QCP-01-quick-capture.md
  - AC2: ✅ artifact: docs/adr/ADR-QCP-01-quick-capture.md
  - AC3: ✅ artifact: docs/adr/ADR-QCP-01-quick-capture.md
  - AC4: ✅ artifact: docs/adr/ADR-QCP-01-quick-capture.md
  - AC5: ✅ artifact: docs/adr/ADR-QCP-01-quick-capture.md
  - AC6: ✅ artifact: docs/test-plans/device/QCP-01.md
- **Decisions:** ADR-QCP-01 (Proposed; awaiting human approval, QCP-02/03 stay blocked until Accepted)
- **Follow-ups:** AUD-13 (Live Activity) and AUD-14 (ShareExtension wiring) proposed; QCP-02 must add its new extension directory to `check_recording_policy.py` source roots.

- 2026-10-17 human decisions recorded: ADR-QCP-01 Accepted (navigate-only everywhere, no start-now, Action Button deferred, Live Activity deferred to AUD-13, AUD-14 filed); SEC-09 Amendments 1 and 4 applied; QCP-02/03 rewritten. Status stays review.
