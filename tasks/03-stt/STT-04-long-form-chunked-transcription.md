# STT-04 — Long-Form Chunked Transcription (> 15 min)

**Workstream:** STT | **Phase:** 2 | **Size:** L | **Depends on:** STT-03, AUD-03 | **Source:** §5 Phase 2 (optimize chunking for streams > 15 min)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-whisper-stt, vv-pipeline-orchestrator, vv-audio-capture, vv-local-database, vv-benchmark-eval, vv-testing

## Goal
Transcribe multi-hour recordings with bounded memory, resumability and accurate stitching.

## Scope
- [x] Segment audio on VAD boundaries into 30–120 s speech windows (whisper seeks internally in 30 s), never cutting mid-word; pass windows to native as `vv_audio_range` lists (`vv_stt_transcribe_ranges`) — no temp WAVs.
- [x] Near-real-time mode uses the CPU backend while backgrounded on iOS (no Metal in background).
- [x] Persist per-chunk results so a killed job resumes at the next chunk (FND-05).
- [x] Carry previous-chunk text as prompt for continuity; detect and drop repetition loops/hallucinations.
- [x] Optional near-real-time mode: transcribe chunks while recording continues (so results are ready at stop).
- [x] Map chunk-local timestamps back to global recording time.

## Acceptance Criteria
- 2-hour recording transcribes with peak RAM stable (no growth) and resumes correctly after a forced kill.
- WER on stitched long-form within 1 pt of per-chunk WER on QA corpus.
- Real-time mode: transcript available ≤ 60 s after stopping a 30-min recording on flagship devices.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-04-long-form-chunked (base origin/main; not stacked) · **Date:** 2026-10-14
- **AUD-03 status:** its branch only holds the claim commit, so STT-04 is built against a
  `VadEngine` interface (`app/lib/core/platform/vad_engine.dart`, fake in tests) and the
  `speech_segments` table AUD-03 will fill. Without stored spans and without a VAD engine, windows
  fall back to chunk boundaries (the pre-VAD behaviour) — nothing breaks before AUD-03 lands.
- **Summary:**
  - `features/transcription/domain/window_planner.dart` — `planWindows`: 30–120 s windows filled
    greedily from VAD spans, cut only in silences between spans (a span > 120 s — continuous speech
    without any VAD silence — is the only hard cut), pauses ≤ 2 s kept, longer silences removed,
    intervals intersected with the chunk files → `WindowRange(path, fileStart, fileEnd,
    recordingOffset)`; `horizonMs` mode returns only final windows and is a prefix of the complete
    plan (property-tested), which is what makes near-real-time results reusable.
  - `hallucination_guards.dart` — no-speech (`no_speech_prob > 0.6 && avg_logprob < −1`), known
    phrases (whole segment only), 3-gram ≥ 4× loops, duplicate of previous segment (also across
    windows), zlib ratio > 2.4; `carryPrompt` (vocabulary + ~200-char tail at a word boundary).
  - `core/platform/stt_engine.dart` — `SttAudioRange` + `WindowedSttEngine.transcribeRanges`;
    `WhisperSttEngine` implements it over `vv_stt_transcribe_ranges` (native concatenation, no temp
    WAVs) and maps segment times to the recording timeline (range offset + `t*_src_ms`; tokens
    shifted by the segment's concat→recording delta).
  - `TranscribeStep` (FND-05 step, additive): windowed path when the engine supports ranges —
    stored spans or VAD once (stored), plan, per window decode → guards → segments
    (`seq = window·100000 + i`) committed with checkpoint `{nextWindow, modelId, paramsHash}`
    (hash covers model, language and the window plan); resume continues at the next window and
    re-seeds the prompt from the last stored segments; legacy per-chunk path kept for engines
    without ranges. `PipelineEngines` gains optional `vad` + `windowCache`.
  - Near-real-time: `LiveTranscriber` (decodes final windows while recording, serialized,
    `canRun` gate for "no other heavy model"), `LiveTranscriptionService` (follows chunks +
    `speech_segments` in the DB; read-only — never starts/extends a recording, SEC-09),
    `FileWindowResultCache` (`<root>/work/live/<id>.json`, keyed by window audio + model/language;
    cleared when the job finishes), policy `nearRealTimeAllowed` (tier ≥ Mid and charging or > 50 %
    battery; PRODUCT-DECISION default off) and `liveUseGpu` (CPU when backgrounded on iOS).
- **Measurements (host, Apple M3 Pro, whisper.cpp v1.9.5, Metal, greedy, machine heavily shared —
  load avg > 100):** `[STT-04/AC2]` on the STT-07 TTS corpus (5 English clips, 2.5 s gaps, 30 s
  chunk files, energy-VAD spans): base.en-q5_1 per-clip WER 3.61 % → stitched 2.81 %; tiny.en
  4.01 % → 3.61 % (stitched ≤ per-clip + 1 pt). `[STT-04/AC1]` 2 h host run (`VV_STT04_2H=1`, tiny.en, 240 × 30 s chunks → 200 windows, 604 decoded segments): process RSS 365 MB after the first window, max 381 MB in the first quarter, max 193 MB in the second half, 184 MB at the end (peak 389 MB) — no growth; the duplicate guard dropped the verbatim-repeated clip text (kept 10), as intended.
- **Gates (2026-10-14, macOS host):** `dart format` / `flutter analyze` / `dart analyze
  --fatal-infos` clean, `flutter test` all passed (811 + new), native host tests `test/native/*`
  passed (`native/build.sh host`: 23/23 ctest), `pytest tools/ci/tests`, `check_recording_policy`,
  `check_egress`, `check_codegen` OK.
- **Acceptance evidence:**
  - AC1: ⏳ test: [STT-04/AC1]; device: docs/test-plans/device/STT-04.md
  - AC2: ✅ test: [STT-04/AC2]
  - AC3: ⏳ test: [STT-04/AC3]; device: docs/test-plans/device/STT-04.md
- **Decisions:** none new (windowing/guards follow `vv-whisper-stt`); PRODUCT-DECISION:
  near-real-time mode defaults to off.
- **Follow-ups:** STT-10, AUD-03 (implements `VadEngine`), FND-11 (wiring).

## Follow-ups
- STT-10 (proposed): register `LiveTranscriptionService` at app start (watch while a recording is
  `recording`, stop on stop/discard), Settings → Processing toggle "Transcribe while recording",
  `canRun` = pipeline worker idle (HeavyModelGate) + `nearRealTimeAllowed` with battery/thermal
  sources; then run the AC3 device rows.
- AUD-03: implement `VadEngine` (whisper.cpp Silero VAD via `vv_bridge`) and pass it in
  `PipelineEngines(vad: …)`; recordings then get VAD-bounded windows automatically.
- FND-11 / integration: build `PipelineEngines` with `vad` + `FileWindowResultCache(paths.root)`.

