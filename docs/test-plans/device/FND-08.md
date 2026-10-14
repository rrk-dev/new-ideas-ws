# Device verification — FND-08 Background Processing Guardrails

No physical device was available when this was authored. The iOS and Android code has not been
compiled locally (no Xcode / Android SDK on the authoring machine); the CI `ios` / `android`
jobs build it. Host evidence: `app/test/unit/pipeline/background_guard_test.dart`.

Setup: dev build with the FND-11 tiny models installed (see `docs/test-plans/device/FND-11.md`)
and a 30-minute recording (e.g. `jfk.wav` tiled 165× via the STT-03 helper, imported, or a real
30-minute recording). Model: a Low/Mid-tier default (`whisper base.en` + 1B LLM) for realistic
duration.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-08/AC1] | Start processing the 30-min recording, wait for 10 % progress, press Home, lock the phone for 5 min, unlock and open the app. | No crash; job state is `transcribing`/`paused` → continues; finished segments kept (no duplicates); job reaches `done`. | iPhone | iOS 16+ | ⏳ | | |
| [FND-08/AC1] | As above, but leave the phone locked and on the charger overnight. | The BGProcessingTask runs (Xcode console / `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.vaultvoice.processing"]` from the debugger); job completes or pauses at expiration and resumes in the foreground; never `failed`. | iPhone + charger | iOS 16+ | ⏳ | | |
| [FND-08/AC1] | Thermal: Xcode › Devices › Condition › Thermal State = Critical during processing, then Nominal. | Job pauses (`paused`) within one chunk; resumes when nominal. | iPhone | iOS 16+ | ⏳ | | |
| [FND-08/AC2] | Start processing a 60-min recording in the foreground, turn the screen off for 60 min. | "Processing your recording" notification visible with progress the whole time; job completes (or is still running) after 60 min; no ANR. | Android arm64 | API 34 | ⏳ | | |
| [FND-08/AC2] | Same on API 35+ with `adb shell am compat enable FGS_INTRODUCE_TIME_LIMITS <pkg>` and `adb shell device_config put activity_manager media_processing_fgs_timeout_duration 60000`. | After ~1 min `onTimeout`: notification disappears, job `paused` (checkpoint kept), no crash/RemoteServiceException; reopening the app resumes it. | Android arm64 | API 35+ | ⏳ | | |
| [FND-08/AC2] | Battery saver on / "Process only while charging" on and unplugged, auto-processed job. | Job paused; turning saver off / plugging in resumes it. "Process now" ignores both. | Android arm64 | API 26+ | ⏳ | | |
| [FND-08/AC3] | Instruments › Metal System Trace while processing; press Home after extraction started; record 2 min in background. | No Metal command buffers from the app while backgrounded (LLM restarted on CPU); GPU work again after returning. | iPhone (A14+) | iOS 16+ | ⏳ | | |
