# AUD-08 — Recording Screen UI

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, AUD-02, SEC-09 | **Source:** §3 (UX)
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-testing, vv-extraction-profiles, vv-markdown-vault-export

## Goal
One-tap recording with clear state, live feedback and profile pre-selection.

## Scope
- [x] Big record/pause/stop controls, elapsed timer, live waveform/level meter.
- [x] Pre-select extraction profile (or "Auto" — PRF-06) and destination before or after recording.
- [x] Add bookmarks/markers during recording ("important moment") stored as timestamps, surfaced to the LLM prompt.
- [x] Title/tags entry post-recording.
- [~] deferred → AUD-11 (nice-to-have; needs native widget/tile/Control targets and devices) — Quick-start entry points (nice-to-have): home-screen widget, Android quick-settings tile, iOS Control Center control — each must be a deliberate user tap. **No** Shortcuts/App Intents that can run unattended in automations, no scheduled/timer/location starts (SEC-09).
- [x] Consent confirmation step before recording (SEC-07) and "Recording unavailable during calls" state (SEC-09).
- [x] Do not open the microphone before the user taps Record (no pre-capture).

## Acceptance Criteria
- Recording starts within 300 ms of tap (measured from tap, after any consent step) — without opening the mic before the tap.
- Markers persisted with correct `at_ms` and `kind = user` (unit test); their display in the transcript view is verified in STT-06.
- Widget tests cover all recorder states.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-08-recording-ui · **Date:** 2026-10-14
- **Summary:** The real Record tab (`app/lib/features/recording/presentation/recording_screen.dart`)
  replaces the placeholder: big Record/Pause/Resume button (Semantics: action label + state
  value, live-region status line — APP-06 gap), Stop, **Mark** (user marker at the recorded
  time), `mm:ss` timer (repaints itself only), AUD-02 live meter + clipping hint, profile (Auto +
  registry profiles) and destination (Auto + vault folders) pickers, SEC-07 consent dialog for
  `consent_confirmation: required` profiles **before** the microphone opens
  (`recordings.consent_confirmed_at`), "Recording is unavailable during calls" (checked on open via
  CallGuard and on refused starts), pause-cause texts, permission/storage/low-storage messages,
  post-recording details sheet (title, tags, profile/destination, stop reason, Process now).
  On stop the recording is queued in the FND-05 pipeline when `processing.auto_process` is on
  (default), otherwise the sheet offers **Process now** (`PipelineClient.enqueue`, FND-11 wiring
  not on this branch). Dev debug buttons kept; RecoveredRecordingsPrompt and BatteryGuidance still
  wrap the screen. `RecordingSessionService` (`data/recording_session_service.dart`) writes the
  choices; `RecordCaptureBackend` implements `ActiveRecording` (id + recorded time); WriteStep
  honours the chosen destination (settings key `recording.destination.<id>`).
- **Acceptance evidence:**
  - AC1: ⏳ test: [AUD-08/AC1]; device: docs/test-plans/device/AUD-08.md
  - AC2: ✅ test: [AUD-08/AC2]
  - AC3: ✅ test: [AUD-08/AC3]
- **Decisions:** no ADR. PRODUCT-DECISIONs: profile/destination default Auto; consent dialog only
  for `required` profiles (optional = no dialog until SEC-07); details sheet after every stop
  (Later = keep defaults); destination stored as a settings key until a schema migration
  (AUD-12); call state checked once on open (no permanent CallGuard subscription).
- **Stacking:** stacked on task/AUD-02-agc-level-metering (LevelMeterBar, levels provider) merged
  with origin/main. Merge note: AUD-06 (import button on the Record app bar) and AUD-03
  (`silenceWatcherProvider` watched in the Record screen, `PauseCause.silence` text) edit the same
  screen — keep both when integrating (the status switch already has a default branch).
- **Follow-ups:** AUD-11, AUD-12 (proposed).

## Follow-ups
- **AUD-11 (proposed): Quick-start entry points** — home-screen widget, Android quick-settings
  tile, iOS Control (`openAppWhenRun = true`, `isDiscoverable = false`) that only *navigate* to the
  Record tab; the start stays the in-app tap (SEC-09 §4). Needs native targets + devices.
- **AUD-12 (proposed): Per-recording destination column** — move `recording.destination.<id>`
  from the settings table into `recordings.target_id` with the next schema migration; delete it
  with the recording (SEC-04) and let EXP-05/06 routing respect it.
- Codex review 2026-10-15 (open): call state checked once in recording_screen.dart and never cleared after hang-up (Record stays disabled): observe call-state changes / refresh on foreground and test call-ended recovery
