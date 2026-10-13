# APP-04 — Processing Status & Local Notifications

**Workstream:** App UX | **Phase:** 2–3 | **Size:** S | **Depends on:** FND-05 | **Source:** Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-pipeline-orchestrator, vv-flutter-architecture, vv-background-execution, vv-testing

## Goal
Users always know where a recording is in the pipeline and when the note is ready.

## Scope
- [x] Per-recording progress (step, %, ETA based on measured RTF / tok/s).
- [x] Global queue indicator.
- [x] Local notifications: "Note ready — Meeting with …" (tap opens result), failures with action.
- [x] Notification content respects privacy setting (generic text on lock screen by default).

## Acceptance Criteria
- ETA within ±30% on test devices; notifications deep-link correctly on both platforms.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/APP-04-processing-status · **Date:** 2026-10-13
- **Summary:** `app/lib/features/pipeline/domain/` — `throughput.dart` (`ThroughputStats`: per-step
  seconds-per-audio-second, running mean → EMA over 5 runs, outlier guard, persisted in `settings`
  key `pipeline.throughput.v1`), `eta.dart` (`estimateRemaining`: measured factor × audio for every
  remaining step, current step blended with live extrapolation weighted by progress; `null` =
  "Estimating time…" instead of a guess; `ThroughputObserver` measures uninterrupted step runs from
  `jobs` snapshots, drops paused/failed runs, normalises resumed ones), `job_progress.dart`
  (views, queue positions, overall %), `processing_notification.dart` (generic lock-screen text by
  default, title only with `notifications.show_details`; Retry action on failures; stable ids),
  `local_notifier.dart` (interface). `data/processing_monitor.dart` (UI-isolate observer: stats,
  notifications on entering `done`/`failed`, just-in-time permission once, tap/Retry routing with a
  deep-link allowlist), `data/flutter_local_notifier.dart` (flutter_local_notifications 22.3.1;
  Android channel "Processing" low importance, `private` visibility when content is shown; iOS
  category with foreground Retry). `presentation/` — `ProcessingStatusCard` (step, %, ETA, queue
  position, Cancel/Retry/Process now), `RecordingStatusScreen` (`/library/recordings/:recordingId`,
  notification target), `ProcessingQueueScreen` (`/library/processing`), `ProcessingQueueIndicator`
  (above the tab bar in `AppShell`), `ProcessingServicesHost` (starts the monitor in `bootstrap`).
  Typed routes in `core/routing/app_routes.dart`. Android core-library desugaring; iOS
  `UNUserNotificationCenter` delegate. Dependency review rows in `docs/privacy-audit.md`.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/APP-04.md; ✅ test: [APP-04/AC1]
- **Decisions:** no ADR (library named by `vv-flutter-architecture`; dependency review recorded).
  Extraction ETA uses LLM seconds per audio second (proxy for tok/s: transcript length scales with
  speech) because token counts are not in `jobs`; revisit when LLM-04 persists token metrics.
- **Follow-ups:** APP-07 (proposed) — notify on `waiting` reasons that need the user (model
  missing, vault access) and show live (non-checkpoint) progress via `PipelineClient.events`.

## Follow-ups
- APP-07 (proposed): notifications for `waiting` reasons that need the user (model missing, vault access lost); live in-step progress from `PipelineClient.events` between checkpoints.
