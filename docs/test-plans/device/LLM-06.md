# Device verification — LLM-06 Long-transcript handling (map-reduce)

Host-verified (no device needed): token-budget planner, chunker (segment/speaker boundaries,
~10% overlap), deterministic reduce, per-chunk checkpoints with kill/resume through the pipeline,
progress per chunk, and "every LLM call fits n_ctx" for a synthetic 2-hour transcript
(`[LLM-06/AC1]` in `app/test/unit/extraction/long_transcript_test.dart`,
`app/test/unit/pipeline/long_transcript_pipeline_test.dart`; real llama.cpp tokenizer + grammar +
SmolLM2 in `app/test/unit/extraction/long_transcript_host_test.dart`). KV prefix reuse: ctest
`vv_llm_prefix` (`native/tests/llm_prefix_test.c`).

AC1 needs a 6 GB phone and the full pipeline (recording → STT → extract → export, wired by the
pipeline/profiles owners with `ExtractStep(longTranscript: …)`). AC2 needs the PRF-09 long-meeting
eval set (see `docs/long-transcripts.md` → Recall methodology).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-06/AC1] | 1. Dev build with the Mid-tier default LLM (3B Q4_K_M, or the LLM-08 default) and `ExtractStep(longTranscript: …)` wired. 2. Import a 2-hour meeting WAV (PRF-09 long fixture or a synthetic `say`-generated meeting, 16 kHz mono). 3. Run the pipeline to the exported note, screen on. 4. Repeat with the app backgrounded after extraction starts. 5. Capture Xcode memory gauge / `os_proc_available_memory` log during extract | Note exported both runs; no JetsamEvent for the app (Settings → Privacy → Analytics); extraction log shows `mapReduce` with ≥ 8 chunks; peak footprint during extract ≈ the LLM-07 estimate for n_ctx (does not grow chunk over chunk) | VV-IOS-14 (6 GB iPhone) | iOS 16+ | | | |
| [LLM-06/AC1] | Same as above on Android (`adb shell dumpsys meminfo com.vaultvoice.vaultvoice.dev` every chunk; `adb logcat -b events \| grep am_kill`) | Note exported; no `am_kill` / lowmemorykiller for the app; PSS stable across chunks | VV-AND-7 (≥ 6 GB Snapdragon 7) | Android 12+ | | | |
| [LLM-06/AC1] | During the 2-hour extract: force-stop the app after ≥ 2 map chunks finished (`adb shell am kill` / Xcode stop), relaunch | Job resumes in `extracting` with the finished chunks skipped (progress resumes, not 0); the note matches an uninterrupted run's action items | VV-IOS-14 or VV-AND-7 | — | | | |
| [LLM-06/AC2] | Run `make eval PROFILE=meeting MODEL=<default gguf>` on the PRF-09 set, split `short` (single pass) vs `long` (≥ 60 min, map-reduce) per `docs/long-transcripts.md` | action-item recall(long, map-reduce) ≥ recall(short, single pass) − 0.10 | host build (eval) + one device run of the long subset | — | | | |

## Notes / evidence
Host runs and the prefix-reuse measurement are in `tools/bench/results/2026-10-14-llm06-map-reduce.md`.
Paste device logs under `docs/test-plans/device/evidence/LLM-06/`.
