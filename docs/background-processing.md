# Background processing (FND-08)

How transcription/extraction behave when the app leaves the foreground. Code:
`app/lib/features/pipeline/data/background_guard.dart` (UI isolate),
`app/lib/features/pipeline/domain/processing_conditions.dart` (hold rules),
`ios/Runner/ProcessingPlugin.swift`, `android/.../ProcessingService.kt` + `ProcessingPlugin.kt`.
OS rules verified against Apple BackgroundTasks / UIKit docs (iOS 16–26) and the Android
foreground-service docs for API 34–36 (October 2026).

## Model
- Every pipeline chunk is a checkpoint (FND-05). "Pausing" a job = `PipelineClient.pause`, which
  stops the step at once; it resumes from its last checkpoint.
- The guard pauses only jobs it paused itself (`settings: pipeline.auto_paused`) and resumes
  exactly those; a job the user paused is never resumed automatically.
- The worker gets the foreground state (FND-11 `PipelineConditions.setForeground`): STT and LLM
  choose the CPU in the background; a running GPU generation is cancelled and re-run on the CPU
  (`LlmService.onBackgrounded`), whisper picks the CPU at the next chunk.

## Hold rules
| Condition | Effect | "Process now" overrides? |
|---|---|---|
| Thermal `critical` (iOS) / `SEVERE`+ (Android) | pause | no |
| Thermal `serious` / `MODERATE` | pause | yes |
| OS background budget expiring | pause until foreground | no |
| Low Power Mode / battery saver | pause | yes |
| "Process only while charging" and unplugged | pause | yes |

## iOS
- While work is pending the plugin holds a `beginBackgroundTask` assertion (≈ 30 s of
  continuation after the user leaves the app); its expiration handler sends `expiring`.
- On leaving the foreground with work pending a `BGProcessingTaskRequest`
  (`requiresExternalPower = true`, identifier `com.vaultvoice.processing` in
  `BGTaskSchedulerPermittedIdentifiers`, `UIBackgroundModes: processing`) is submitted. When iOS
  runs it, the guard resumes the queue on the CPU and calls `setTaskCompleted` when idle; the
  expiration handler pauses.
- **Audio session evaluated and rejected:** keeping an `AVAudioSession` active to stay alive is
  legitimate only while a user-started recording runs (SEC-09, App Review). Processing never uses
  the audio background mode; a recording in progress already keeps the app alive (AUD-04).
- iOS 26 `BGContinuedProcessingTask` (user-started long jobs with a Live Activity) is a follow-up.

## Android
- `ProcessingService`: foreground service of type `dataSync` (API ≤ 34) / `mediaProcessing`
  (API 35+), started only while the app is visible (`fgs_refused` otherwise — the job then runs
  on checkpoints as long as the process lives), with a generic progress notification. Android 15+
  6 h / 24 h budget: `onTimeout` → `expiring` → pause, service stops immediately.
- The engine is retained while the service runs (MainActivity), like recording.
- Deferred ("charge only") jobs on Android resume when the app is next opened with the charger
  connected; WorkManager scheduling (with a headless engine) is follow-up FND-12.
