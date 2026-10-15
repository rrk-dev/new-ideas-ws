# Device verification — STT-04 Long-Form Chunked Transcription (> 15 min)

Host evidence: `[STT-04/AC1]` (kill/resume, bounded windows — `app/test/unit/transcription/
long_form_transcription_test.dart`; 2 h RSS run — `app/test/native/long_form_memory_test.dart`,
opt-in), `[STT-04/AC2]` (`app/test/native/long_form_wer_test.dart`), `[STT-04/AC3]` (cache reuse
leaves ≤ 1 window after stop). These rows are the on-device acceptance runs.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-04/AC1] | 1. Import (AUD-06) or record a 2 h meeting-style file. 2. Process with the tier default model; sample `vv_proc_memory` every 30 s (FND-07 metrics / Instruments Allocations / `dumpsys meminfo`). 3. At ~40 % force-kill the app (swipe away / `adb shell am force-stop`). 4. Relaunch. | Peak RSS flat across windows (last-hour max ≤ first-15-min max + 64 MB). After relaunch the job resumes at the next window (progress continues from the checkpoint, no restart from 0 %), finishes, and the transcript has no duplicated or missing passages around the kill point. | iPhone 11 (4 GB) | iOS 18.x | ⏳ | | |
| [STT-04/AC1] | Same as above. | Same as above. | Pixel 7 | Android 15 | ⏳ | | |
| [STT-04/AC3] | 1. Enable near-real-time transcription (device on charger). 2. Record 30 min of conversation, then tap Stop. 3. Measure stop → transcript visible in the transcript screen. 4. Repeat with the app backgrounded for the last 10 min (iOS: confirm CPU backend in diagnostics). | Transcript available ≤ 60 s after Stop on flagship devices; no recording behaviour changes (indicator, call guard). | iPhone 15 Pro | iOS 18.x | ⏳ | | |
| [STT-04/AC3] | Same as above. | Same as above. | Pixel 8 Pro | Android 15 | ⏳ | | |

## Notes / evidence
Memory traces and timings under `docs/test-plans/device/evidence/STT-04/`. Near-real-time needs
the recording-controller hook (follow-up STT-10) before AC3 can be run on a device.
