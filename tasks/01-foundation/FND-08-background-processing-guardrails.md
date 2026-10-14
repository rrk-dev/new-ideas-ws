# FND-08 — Background Processing Guardrails (iOS & Android)

**Workstream:** Foundation | **Phase:** 4 (design in Phase 2) | **Size:** L | **Depends on:** FND-05, STT-03, LLM-04 | **Source:** §5 Phase 4
**Status:** review
**Skills:** vv-task-workflow, vv-background-execution, vv-pipeline-orchestrator, vv-flutter-architecture, vv-whisper-stt, vv-llm-inference, vv-testing

## Goal
Transcription/extraction continue or safely pause when the app is backgrounded, within each OS's rules.

## Scope
- [x] iOS: `beginBackgroundTask` for short continuation; `BGProcessingTask` (requires-external-power option) for long jobs; checkpoint before expiration handler fires.
- [x] iOS: evaluate keeping processing alive while an audio session is active (only legitimate during recording).
- [x] iOS: GPU (Metal) work is not permitted in background — fall back to CPU or pause and resume on foreground.
- [x] Android: foreground service (type `dataSync` (API ≤ 34) / `mediaProcessing` (API 35+), 6 h/24 h limit with `onTimeout`) with progress notification.
- [~] Android: WorkManager for deferred jobs — deferred → FND-12 (needs a new Gradle dependency and a headless Flutter engine for the Dart pipeline; deferred jobs resume on the next app open meanwhile).
- [x] Thermal state & low-power mode awareness: throttle or defer.
- [x] User setting: "Process only while charging" / "Process now".

## Acceptance Criteria
- iOS: backgrounding during a 30-min transcription never crashes; job resumes or completes.
- Android: processing survives screen-off for 60 min on a test device with notification visible.
- No Metal GPU usage while backgrounded (verified in Instruments).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-08-background-guardrails (stacked on task/FND-11-production-engine-wiring — uses its worker lifecycle forwarding) · **Date:** 2026-10-14
- **Summary:** `BackgroundProcessingGuard` (`app/lib/features/pipeline/data/background_guard.dart`, started by
  `ProcessingServicesHost`) holds the OS keep-alive while work is pending and pauses/resumes jobs (= checkpoint) on
  holds (`domain/processing_conditions.dart`: thermal critical/serious, Low Power Mode, the charge-only setting,
  background budget expiring; "Process now" overrides only the power settings and `serious`). It resumes only the
  jobs it paused (`pipeline.auto_paused`), schedules/completes deferred processing and starts the worker when
  runnable jobs exist (recovery at launch). Port: `domain/background_platform.dart`,
  `data/method_channel_background_processing.dart`. iOS `ios/Runner/ProcessingPlugin.swift`
  (`beginBackgroundTask`, `BGProcessingTask` with external power, thermal / low-power / battery observers;
  Info.plist `UIBackgroundModes: processing` + `BGTaskSchedulerPermittedIdentifiers`). Android
  `ProcessingService.kt` (FGS `dataSync` / `mediaProcessing`, `onTimeout`, generic progress notification) and
  `ProcessingPlugin.kt` (thermal listener, charger / battery-saver broadcasts); the engine is retained while the
  service runs. GPU in the background: FND-11 forwarding → CPU backends, a GPU generation re-runs on the CPU.
  Design + audio-session evaluation: `docs/background-processing.md`. New l10n keys
  `notificationProcessingOngoingTitle/Body`. AUD-05's manifest test updated for the third (non-microphone) FGS.
- **Acceptance evidence:**
  - AC1: ⏳ test: [FND-08/AC1]; device: docs/test-plans/device/FND-08.md
  - AC2: ⏳ test: [FND-08/AC2]; device: docs/test-plans/device/FND-08.md
  - AC3: ⏳ test: [FND-08/AC3]; device: docs/test-plans/device/FND-08.md
- **Decisions:** no ADR (OS mechanisms prescribed by vv-background-execution). PRODUCT-DECISIONs: thermal `serious`
  pauses automatic jobs but not "Process now"; Low Power Mode defers automatic jobs; the Android notification is
  generic.
- **Not built locally:** no Xcode / Android SDK on the authoring machine (doctor.sh) — the Swift/Kotlin code
  compiles only in CI.
- **Follow-ups:** FND-12 (below); iOS 26 `BGContinuedProcessingTask` for user-started long jobs; fewer STT/LLM
  threads at thermal `serious` instead of pausing.

## Follow-ups
- FND-12 (proposed): Android WorkManager scheduling for "process only while charging" jobs (charging constraint,
  headless engine, `setForeground` only while visible).
