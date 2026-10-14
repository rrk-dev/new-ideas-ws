# ADR-AUD-05 — Android background recording: microphone FGS as a keep-alive + indicator

- **Status:** Accepted (engineering); Kotlin compile-checked only by CI (no local Android SDK),
  device rows pending (docs/test-plans/device/AUD-05.md)
- **Date:** 2026-10-13
- **Task:** AUD-05
- **Deciders:** Claude Code (implementer); pending independent verifier
- **Builds on:** ADR-AUD-01-recording-service, ADR-SEC-09-recording-policy
- **Verified against:** Android API reference for compileSdk 36 (foreground-service types and the
  Android 14 while-in-use restriction, `Notification.Builder`, `ServiceInfo`), Flutter embedding
  `FlutterActivity` (`provideFlutterEngine`, `shouldDestroyEngineWithHost`) on Flutter 3.47.7.

## Context
A recording the user starts must survive backgrounding, screen-off and OEM battery managers, while
staying visible (SEC-09 §6) and never capturing calls. Android requires a foreground service of type
`microphone` (+ `FOREGROUND_SERVICE_MICROPHONE`) for microphone access while not visible, and
Android 14+ forbids *starting* such a service from the background.

## Options considered
1. **Thin `RecordingService` (FGS type microphone) as keep-alive + notification; capture stays in
   the Flutter engine (`record` plugin) (chosen).** One capture path (AUD-01) on both platforms;
   the service only holds the process/while-in-use access and shows Pause/Resume/Stop.
2. Move capture into the service (native `AudioRecord` → chunk writer in Kotlin) — survives engine
   loss, but duplicates AUD-01's writer, discard and recovery logic natively and re-opens the
   "who may open the mic" question outside `RecordingController`.
3. A plugin such as `flutter_foreground_task` — adds a dependency, its own isolate model and
   permissions surface (dependency review) for ~200 lines of code we can own.

## Decision
- `RecordingService` (`android:foregroundServiceType="microphone"`, `exported=false`) is started by
  `RecordingIndicatorPlugin.show` **only** from `RecordingIndicatorBinding` on the first
  `recording` state — i.e. right after the user's tap opened the microphone with the activity
  visible. `startForeground(…, FOREGROUND_SERVICE_TYPE_MICROPHONE)` immediately (API 30+; 2-arg
  form below). Refusals (`ForegroundServiceStartNotAllowedException`, `SecurityException`) are
  returned to Dart as `Err`.
- `START_NOT_STICKY`; an intent without the plugin's spec stops the service: the system can never
  restart a recording on its own.
- Ongoing notification (`IMPORTANCE_LOW` channel "Recording", `FOREGROUND_SERVICE_IMMEDIATE`,
  public on the lock screen — it contains only the state): chronometer while recording; Pause/Stop
  while recording, Resume/Stop while paused; "Recording paused because a call started — Audio from
  the call was not recorded. Tap Resume to continue." after a call (SEC-09 draft copy). Android 14+
  lets users swipe FGS notifications away: the delete intent re-posts it. The 60-min "Still
  recording" reminder (SEC-09) uses a separate default-importance channel.
- Notification buttons → `PendingIntent.getService` → `RecordingService.onAction` → event channel →
  Dart `RecordingIndicatorBinding` → `RecordingController.pause()` / `.resume(ResumeSource
  .recordingNotification)` / `.stop()`. Resume re-checks CallGuard, so it is refused during a call.
- **Engine lifetime:** while the service runs, `MainActivity.shouldDestroyEngineWithHost()` returns
  false and the engine is kept in `RetainedEngine`; `provideFlutterEngine` hands it to the next
  activity. So swiping the app away does not kill the Dart capture code. Without a running
  recording the engine is destroyed with the activity as before.
- **Calls in background:** unchanged SEC-09 `CallGuardPlugin` (audio mode listener / 500 ms poll +
  `AudioRecordingCallback.isClientSilenced`) keeps running in the retained engine's process; AUD-01
  discards post-event audio. Concurrent capture by another app (Android 10+ silences one client) is
  reported by `isClientSilenced` (→ `captureSilenced` pause) or by the `record` stream pausing /
  failing (→ `interrupted` / `captureFailed` pause); never resumed automatically.
- `POST_NOTIFICATIONS` (API 33+) is requested once on the first start; if denied, the FGS still runs
  and Android's own microphone privacy indicator (API 31+) and the FGS task-manager entry remain
  (PRODUCT-DECISION: recording is not blocked on notification permission).
- **OEM battery managers:** `BatteryGuidance` card (Samsung, Xiaomi/Redmi/POCO, OnePlus/OPPO/realme,
  vivo, Huawei/Honor) when `PowerManager.isIgnoringBatteryOptimizations` is false, with a button to
  `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` (fallback: app details). We never declare or use
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Play policy).
- Plain method/event channels (`vaultvoice/recording_indicator[/actions]`) like CallGuard.

## Consequences
- Positive: no new dependency; the policy-relevant code paths stay in Dart and are unit-tested with
  fakes; the Play declaration is a single, honest microphone FGS (docs/play-console/fgs-declaration.md).
- Negative / risks: Kotlin not compiled locally (CI `android` job); engine retention relies on
  documented `FlutterActivity` hooks — device rows cover swipe-away; if the OS kills the process
  anyway, AUD-07 recovers the audio. Lock-screen visibility `PUBLIC` shows "Recording" on the lock
  screen (intended: always visible).
