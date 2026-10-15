# APP-04 — Processing Status & Local Notifications

**Workstream:** App UX | **Phase:** 2–3 | **Size:** S | **Depends on:** FND-05 | **Source:** Gap
**Status:** review
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
  - AC1: ⏳ device: docs/test-plans/device/APP-04.md; test: [APP-04/AC1]
- **Decisions:** no ADR (library named by `vv-flutter-architecture`; dependency review recorded).
  Extraction ETA uses LLM seconds per audio second (proxy for tok/s: transcript length scales with
  speech) because token counts are not in `jobs`; revisit when LLM-04 persists token metrics.
- **Follow-ups:** APP-07 (proposed) — notify on `waiting` reasons that need the user (model
  missing, vault access) and show live (non-checkpoint) progress via `PipelineClient.events`.

## Follow-ups
- APP-07 (proposed): notifications for `waiting` reasons that need the user (model missing, vault access lost); live in-step progress from `PipelineClient.events` between checkpoints.
## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ · analyze ✅ · tests ✅ (780 passed, 29 skipped; coverage not re-measured locally, CI test job gates ≥80% and is green) · native smoke n/a (no native/bridge change) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51 of ci, commit 67b6fcf, completed successfully; run 50 also succeeded)
- **Acceptance criteria:**
  - AC1: ✅ host re-ran `[APP-04/AC1]`. `eta_test.dart` learns throughput on two recordings, then checks a 20% slower run stays within ±30% of the simulated remaining time at every 10% checkpoint, and a mis-calibrated run converges via live progress; with no measurement the ETA is null ("Estimating time…"), not a guess. `processing_monitor_test.dart` asserts generic lock-screen text by default, title only when details are enabled, an allowlist of processing routes, note-ready deep link, and failure Retry. Widget test checks the typed route. Device rows in `docs/test-plans/device/APP-04.md` (ETA and notification deep links on iOS and Android) are blank (⏳). Mutation: forced `estimateRemaining` to 1µs; the ±30% test failed; restored
- **Adversarial checks:** queued job with no live progress; paused/failed runs dropped by the observer (unit tests around the tagged case); notification `toString` omits the title; deep-link allowlist rejects non-processing payloads; details default off so the recording title is not on the lock screen. No new network host.
- **Skill/rule compliance:** local notifications via `flutter_local_notifications` (named by `vv-flutter-architecture`), dependency row in the privacy audit. ETA uses audio-seconds because token counts are not on `jobs` (recorded). No credentials or certificates.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/APP-04.md has no PASS result with a date; dependency FND-05 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
