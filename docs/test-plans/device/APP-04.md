# Device verification — APP-04 Processing Status & Local Notifications

Host tests cover the ETA model (`[APP-04/AC1]` in `app/test/unit/pipeline/eta_test.dart`:
learned throughput + 20 % slower run stays within ±30 % at every checkpoint), notification
content/privacy, the Retry action, the deep-link allowlist and typed-route navigation
(`processing_monitor_test.dart`, `test/widget/processing_status_test.dart`). These rows confirm
real throughput, the OS notification UI, lock-screen privacy and deep links on devices, which
could not be run when this was authored (no Xcode / Android SDK / devices).

Prerequisite: a build where the pipeline engines are wired (STT-03 / LLM-04 / EXP-05 overrides of
`pipelineEnginesFactoryProvider`) and the test models are installed (`tools/ci/fetch_test_models.sh`).
"ETA error" = |shown ETA − actual remaining time| / actual remaining time.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [APP-04/AC1] ETA (iOS) | 1. Fresh install, dev flavor. 2. Process two 5–10 min recordings to completion (calibration; `settings` key `pipeline.throughput.v1` now has `transcribe` and `extract`). 3. Start a 20–30 min recording's processing; keep the app open on Library → Processing (or the recording's status screen). 4. Note the shown ETA and wall-clock time at 10 %, 25 %, 50 %, 75 %, 90 % progress; note when the note is ready. | At each sampled point the ETA error is ≤ 30 %. Before calibration (step 2's first run) the card says "Estimating time…" instead of a made-up number. | iPhone (A15+) | iOS 16+ | | | |
| [APP-04/AC1] ETA (Android) | Same as above. | Same: ETA error ≤ 30 % at every sampled point. | arm64 Android, 6–8 GB RAM | API 26+ | | | |
| [APP-04/AC1] Notifications deep link (iOS) | 1. First processing job → the system permission prompt appears once (after the job is queued, not at launch); allow. 2. Background the app while processing; wait for the note. 3. Tap "Your note is ready". 4. Repeat with the app force-quit after queueing (relaunch by tap). 5. Force a failure (e.g. revoke the vault folder / delete the model mid-run until it fails) → tap the "Retry" action. | 2: banner + lock screen show the generic text "Your note is ready" with no recording title. 3/4: app opens on Library → Processing → the recording's status screen (Back returns to Library). 5: the job is re-queued and the status screen opens. With Settings → "Show details in notifications" on, the title appears only when unlocked (system "Show Previews: When Unlocked"). | iPhone | iOS 16+ | | | |
| [APP-04/AC1] Notifications deep link (Android) | Same steps 1–5; on Android 13+ the POST_NOTIFICATIONS prompt appears once in step 1. Also check the notification's channel is "Processing" (long-press → settings) with low importance. | Same as iOS. Lock screen with details on shows "Lumen — Contents hidden" (visibility private); with details off it shows the generic text. Tapping Retry opens the app and re-queues the job. | arm64 Android 13+ (and one API 26–32 device for no-runtime-permission path) | API 26+ | | | |

## Notes / evidence
Put the ETA samples (table: progress %, shown ETA, actual remaining, error %) and screenshots of the
lock screen under `docs/test-plans/device/evidence/APP-04/`.
