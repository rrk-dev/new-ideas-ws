---
name: vv-background-execution
description: "Running work while backgrounded on iOS and Android: background audio, BGProcessingTask, BGContinuedProcessingTask, no GPU in background, foreground service types and time limits, WorkManager, thermal/low-power. Use for background recording, processing or downloads."
---

# Background Execution

OS rules here change yearly. Before implementing, re-check current Apple
(BackgroundTasks, AVAudioSession) and Android (foreground service types, Android 14/15/16
behavior changes) docs, and note the OS versions you verified against in the code.

## iOS
| Need | Mechanism | Notes |
|---|---|---|
| Keep recording when locked | `UIBackgroundModes: audio` + active `AVAudioSession` | Only for a recording the user started by tap (SEC-09); never start recording from background. Do **not** play silent audio to stay alive (App Review rejection). |
| Finish a short step after user leaves | `UIApplication.beginBackgroundTask(expirationHandler:)` | ~30 s; checkpoint + `endBackgroundTask` in the expiration handler. |
| Long transcription/extraction later | `BGProcessingTaskRequest` (`requiresExternalPower = true`; `UIBackgroundModes` must include `processing`; identifier in `BGTaskSchedulerPermittedIdentifiers`) — runs backgrounded → CPU backend only | System decides when (often overnight/charging). Always checkpoint; handle `expirationHandler`. |
| User-started long job continuing in background (iOS 26+) | `BGContinuedProcessingTaskRequest(identifier:title:subtitle:)` | Submit from foreground on a user tap; update `task.progress` continuously (user can cancel from the Live Activity → expirationHandler); `strategy` `.queue`/`.fail`. GPU: entitlement `com.apple.developer.background-tasks.continued-processing.gpu` + `requiredResources = .gpu` only if `BGTaskScheduler.supportedResources.contains(.gpu)` — reportedly false on current iPhones, so CPU is the normal iPhone path. Fall back on iOS < 26. |
| Model downloads | `URLSession` background configuration | Survives app suspension/termination; handle `handleEventsForBackgroundURLSession`. |

**GPU:** Submitting Metal work from a backgrounded app fails (command buffers error/abort)
unless the iOS 26 continued-processing GPU entitlement applies. Therefore: on
`didEnterBackground`, the pipeline either (a) switches the current job to CPU backend at the
next chunk boundary, or (b) pauses and checkpoints. Never let an in-flight Metal call run into
background — listen for `willResignActive` and stop submitting.

## Android
| Need | Mechanism | Notes |
|---|---|---|
| Recording | FGS type `microphone` | Must start from foreground (Android 14+ while-in-use restriction). |
| Long processing | FGS type `dataSync` (≤ API 34) / `mediaProcessing` (API 35+, intended for media/transcoding — verify fit) | Targeting API 35+: both have a 6 h per 24 h limit shared across services of that type (resets when the app comes to foreground; once exhausted, starts throw `ForegroundServiceStartNotAllowedException`); implement `Service.onTimeout(int, int)` → checkpoint, `stopForeground()`, `stopSelf()` within seconds (else ANR/`RemoteServiceException`). `mediaProcessing` needs `FOREGROUND_SERVICE_MEDIA_PROCESSING`. Starting these from background is restricted — start when user taps "Process" or right after recording while still foreground. |
| Deferred processing | WorkManager `CoroutineWorker` with constraints (charging, storage not low), chunked + resumable | Use for "process only while charging". Call `setForeground(...)` only if the worker starts while the app is visible — from background it throws `ForegroundServiceStartNotAllowedException` (Android 12+): catch it and continue with checkpoints. Targeting API 34+: declare `androidx.work.impl.foreground.SystemForegroundService` with `android:foregroundServiceType="dataSync|mediaProcessing"` + `tools:node="merge"`, pass the type in `ForegroundInfo`. |
| Downloads | WorkManager (or DownloadManager) with resumable range requests | |
Doze/App Standby: FGS work keeps running; plain background threads don't. OEM killers:
guidance screen + test on Samsung/Xiaomi.

## Thermal & power (both)
- iOS `ProcessInfo.thermalState` (`.serious` → reduce threads/pause; `.critical` → pause),
  `isLowPowerModeEnabled` → defer unless user forced.
- Android `PowerManager.getCurrentThermalStatus()` / `addThermalStatusListener`
  (`THERMAL_STATUS_SEVERE` → pause), `isPowerSaveMode`.
- Expose as `DeviceConditions` stream to the pipeline; pausing = checkpoint + `paused` state.

## Pipeline integration contract
- The pipeline worker exposes `pauseAtNextCheckpoint()` and `resume(backend: cpu|gpu)`.
- Every chunk is a safe stop point (STT ~30 s audio, LLM one map chunk).
- On app termination nothing special is needed beyond checkpoints (FND-05 resumes on launch).

## Verification
- iOS: background a 30-min transcription → Instruments shows no GPU work while backgrounded;
  job completes or resumes on foreground; no crash.
- Android: screen off 60 min with FGS notification; `onTimeout` path tested with
  `adb shell am compat enable FGS_INTRODUCE_TIME_LIMITS <pkg>` +
  `adb shell device_config put activity_manager data_sync_fgs_timeout_duration <ms>`
  (or `media_processing_fgs_timeout_duration`).
- Thermal: simulate via Xcode Devices "Condition" (thermal state) / Android `adb shell cmd thermalservice override-status 3` (AOSP builds; may be unavailable on some OEM devices).
