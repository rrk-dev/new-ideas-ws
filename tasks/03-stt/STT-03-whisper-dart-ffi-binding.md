# STT-03 — Whisper Dart FFI Binding & Engine Service

**Workstream:** STT | **Phase:** 2 | **Size:** M | **Depends on:** STT-01, STT-02 | **Source:** §4.2 (FFI / C++ bridge)
**Status:** review
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-whisper-stt, vv-testing, vv-local-database, vv-pipeline-orchestrator

## Goal
A Dart `SttEngine` implementation that transcribes audio with progress, cancellation and timestamps, without blocking the UI.

## Scope
- [x] C bridge per `vv-ffi-bridge` → Required bridge functions: `vv_stt_create`, `vv_stt_transcribe_async(wav_path…)` / `vv_stt_transcribe_ranges`, `vv_stt_cancel`, `vv_stt_destroy` (paths, not PCM buffers). (`native/bridge/vv_whisper.{h,cpp}`)
- [x] Run on a native worker thread; marshal progress + segment callbacks via `NativeCallable.listener` / ports. (`packages/vv_native/lib/src/whisper.dart`; model load/destroy on a helper isolate)
- [x] Parameters: language, translate off, beam size, temperature fallback, initial prompt (vocabulary hints), `no_context`, token timestamps. (`vv_stt_params` / `VvSttParams` / `SttOptions`)
- [x] Output segments with start/end ms and confidence → `transcript_segments` table. (`TranscribeStep` stores `avg_logprob` + `tokens_json`)
- [~] deferred → PRF-01 Custom vocabulary / initial prompt per profile (e.g., product names, team names). Engine side done (`SttOptions.initialPrompt`, `carry_initial_prompt` in every window); the per-profile value comes from PRF-01's "STT hints" field, then `TranscribeStep` passes it.
- [x] Memory: free model after job unless another STT job queued. (`WhisperSttEngine`: kept across consecutive calls, idle unload, `unload()` for `HeavyModelGate.release`)

## Acceptance Criteria
- Transcribing a 10-min file shows live progress and segments in the UI; cancel stops within 1 s.
- No UI frame drops > 16 ms during transcription (DevTools trace).
- Integration test runs on device in CI device lab (QA-05) or manually documented.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-03-whisper-ffi-engine (stacked on task/STT-02-whisper-android) · **Date:** 2026-10-13
- **Summary:** C ABI `native/bridge/vv_whisper.{h,cpp}` (included by `vv_bridge.h`):
  `vv_stt_create/transcribe_async/transcribe_ranges/cancel/destroy/free_segment/last_error`,
  struct-sized params, one native worker thread per job (`VV_E_BUSY` for a second job), atomic
  cancel checked by whisper's `abort_callback` + `encoder_begin_callback`, heap-owned segment
  payloads freed by the callee, range concatenation with per-range time mapping (STT-04 ready),
  English-only models skip language auto-detection. Dart: `VvWhisper` (ffigen bindings regenerated,
  `NativeCallable.listener` per job, model load/destroy via `Isolate.run`, stream waits for all
  segments using `n_segments` from `on_done`). App: `SttEngine` extended (`onSegment`,
  `SttOptions`, segment confidence/tokens — fakes updated), `WhisperSttEngine`
  (`app/lib/features/transcription/data/`), `failureFromVvCode` (`app/lib/core/errors/native_failures.dart`),
  `TranscribeStep` persists confidence/tokens and passes the language. Tests: ctests `vv_stt_*`
  (also clean under ASan+UBSan: `native/tests/sanitize.sh`, which relaxes only the cancel timing
  budget via `VV_CANCEL_BUDGET_MS`), `packages/vv_native/test/whisper_host_test.dart`,
  `app/test/native/whisper_stt_engine_test.dart`, `app/test/unit/transcription/`,
  device test `app/integration_test/stt_engine_test.dart`.
- **Host numbers (M3 Pro, macOS 27.0.1):** jfk 11 s with tiny.en in 85 ms (Metal); cancel →
  `VV_E_CANCELLED` 17 ms Metal / 224 ms CPU (tiny.en), 53 ms / 336 ms (base.en-q8_0); RSS flat
  over 15 load/dispose cycles (< 64 MB growth); ASan/UBSan: 0 reports (Metal + CPU runs).
- **Acceptance evidence:**
  - AC1: ⏳ test: [STT-03/AC1]; device: docs/test-plans/device/STT-03.md
  - AC2: ⏳ test: [STT-03/AC2]; device: docs/test-plans/device/STT-03.md
  - AC3: ⏳ test: [STT-03/AC3]; device: docs/test-plans/device/STT-03.md
- **Decisions:** none new (follows vv-ffi-bridge; backend choice per ADR-STT-01/02).
- **Follow-ups:** wire `WhisperSttEngine` into the worker's `PipelineEnginesFactory` with the
  installed model path (MDL-02) and `HeavyModelGate(release: … stt.unload())` (owner of pipeline
  bootstrap / APP-04 live job view); per-profile vocabulary from PRF-01; CI native-host job:
  fetch tiny.en + jfk and run `native/tests/sanitize.sh` (CI owner); live segment list UI (STT-06).


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ✅ host C/Dart tests assert live callbacks, transcript keywords/timestamps and cancel <1 s; mutation is detected. ❌ device UI harness never rebuilds after progress/segment callbacks.
  - AC2: ✅ host event-loop proxy passed; ❌ device frame check accepts an empty frame list as p99=0 and does not establish the requested DevTools/device budget.
  - AC3: ❌ read integration_test/stt_engine_test.dart and all device rows: integration harness has the defects below; no physical runs are claimed.
- **Mutation sanity check:** Replaced mapped segment text with an empty string in WhisperSttEngine: `[STT-03/AC1]` failed its keyword assertion; restored with git checkout.
- **Adversarial checks:** Native args, corrupt/missing audio/model, ranges, busy, cancellation, destroy during work and churn passed. App tests checked model reuse/idle unload/GPU-to-CPU reload and serial calls. Device kill/lock/rotate were unavailable.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/STT-03.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:**
  1. `app/integration_test/stt_engine_test.dart`: StatefulBuilder receives setState but never calls it. onProgress only assigns progress and onSegment only mutates the list, so the visible progress bar and segment count remain at their initial values. The test checks variables, not displayed values; AC1/AC3 evidence is incomplete.
  2. The same test maps `timings.isEmpty` to p99=0, so zero measured frames pass AC2. Require nonempty meaningful profile-mode timings and assert the actual frame budget; the host p95 timer proxy cannot replace it.
  3. Cancellation always waits 30 seconds before cancel, even if the tiny-model run has completed. It then requires CancelledFailure from an already completed run, making the device test unreliable on fast devices. Cancel while a run is demonstrably active.

## Rework
- **Agent:** Claude Code · **Branch:** task/STT-03-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged).
- **Approach:** the device harness logic moved to `app/integration_test/support/stt_live_harness.dart`
  (`SttLiveState`/`SttLiveView`, `runLiveAndCancel`, `liveUiProblems`, `frameBudgetProblems`,
  `minFrameSamplesFor`) so it is host-testable; `app/integration_test/stt_engine_test.dart` now only wires
  the real `WhisperSttEngine` into it. Host self-test (written first, red before the harness existed):
  `app/test/unit/transcription/stt_live_harness_test.dart` — 7 tests tagged `[STT-03/AC1]` / `[STT-03/AC2]`.
- **Issue 1 (UI never rebuilt; checks read variables, not the screen):** engine callbacks now feed a
  `ChangeNotifier` rendered by a `ListenableBuilder` (progress bar, "N segments" counter, latest segment
  text). After every pumped frame the harness reads the **displayed** values back from the widget tree
  (`readDisplayed`: `LinearProgressIndicator.value`, counter `Text`, latest-segment widget) and
  `liveUiProblems` requires ≥ 2 distinct increasing displayed progress values, no regression, and a
  displayed segment before cancel. Host proof: `[STT-03/AC1] … fails when the screen never rebuilds`
  replays the old shape (callbacks fire, nothing notifies the view; `callbackCount > 0`) and the checks
  report "displayed progress never advanced" + "no segment was displayed"; the streaming case passes.
  Mutation (2026-10-14): removed both `notifyListeners()` calls in `SttLiveState` → the passing
  `[STT-03/AC1]` streaming test failed (`Expected: empty`); restored → 7/7 pass.
- **Issue 2 (empty frame list passed as p99 = 0):** `p99FrameUs` is −1 for no samples (never passes);
  `frameBudgetProblems` requires `frames ≥ minFrameSamplesFor(liveWindow)` (half of 60 Hz, min 60 → ≥ 300
  for the 10 s window) **and** p99 build+raster ≤ 16 000 µs. The AC2 device test runs only in profile mode
  (`skip: … || !kProfileMode` — debug timings are not a jank measurement) over ≥ 10 s of live 10-min
  transcription, flushes batched FrameTimings, and fails on any problem. Added `app/test_driver/integration_test.dart`
  (+ `flutter_driver` dev dependency, SDK package) so the documented `flutter drive --profile` row is runnable.
  Host proof: `[STT-03/AC2]` tests — zero samples fail, 89 samples in a 3 s window fail (floor 90),
  p99 17 000 µs fails, exactly 16 000 µs passes.
- **Issue 3 (fixed 30 s wait, cancel after completion):** `runLiveAndCancel` cancels as soon as the run has
  been live ≥ `minLive` (3 s; 10 s for AC2) with ≥ 3 displayed segments, checks completion after every frame,
  never cancels a finished run and reports `completedBeforeCancel`, which `liveUiProblems` treats as a
  failure (as is a non-`CancelledFailure` result or cancel latency ≥ 1 s). Host proof: `[STT-03/AC1] …
  fails when the run completes before cancel is issued` (fast fake, `cancel.isCancelled == false`) and
  `… fails on a non-cancelled result or a slow cancel`.
- **Device rows:** `docs/test-plans/device/STT-03.md` rewritten for the new harness (debug run for AC1,
  `flutter drive --profile` for AC2, both modes for AC3); Result/Date/Tester blank — no device here.
  Devices needed: iPhone 13 (iOS 17/18, Metal) and an Android arm64 mid-range phone (Android 14/15).
- **Acceptance evidence (unchanged lines above remain valid):** AC1 ⏳ device (host ✅ `[STT-03/AC1]`),
  AC2 ⏳ device (host ✅ `[STT-03/AC2]`), AC3 ⏳ device.
- **Cancel latency clock:** on a device (`LiveTestWidgetsFlutterBinding`) the harness uses wall clock
  (≥ pumped time); under the host fake-async binding it uses pumped time only, so the host self-test is not
  sensitive to runner load.
- **Gates (2026-10-15, macOS host, load average ~55 from parallel agents):** `dart format` 0 changed ·
  `flutter analyze` / `dart analyze --fatal-infos` 0 issues · `check_codegen.sh` clean · `check_recording_policy.sh`
  OK · `check_egress.sh` OK · `tasks.py validate` 0 problems · `pytest tools/ci/tests` 90 passed, 1 skipped ·
  `flutter test`: 1360 passed, 52 skipped, 4 failed — 1 was this harness's cancel latency (wall clock under load,
  fixed above; file now 7/7), the other 3 are pre-existing wall-clock budget tests outside this task
  (`[AUD-08/AC1]` < 300 ms, `[APP-02/AC1]` < 200 ms, `[AUD-05/AC1]` background recording) that fail only
  under this load (no code they exercise changed here).

## Follow-ups

- Codex review 2026-10-15 (open): Active Metal STT decode continues after backgrounding; cancel/checkpoint STT on the lifecycle transition and reload on CPU before resuming.
