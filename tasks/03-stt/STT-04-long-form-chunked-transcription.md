# STT-04 — Long-Form Chunked Transcription (> 15 min)

**Workstream:** STT | **Phase:** 2 | **Size:** L | **Depends on:** STT-03, AUD-03 | **Source:** §5 Phase 2 (optimize chunking for streams > 15 min)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-whisper-stt, vv-pipeline-orchestrator, vv-audio-capture, vv-local-database, vv-benchmark-eval, vv-testing

## Goal
Transcribe multi-hour recordings with bounded memory, resumability and accurate stitching.

## Scope
- [ ] Segment audio on VAD boundaries into 30–120 s speech windows (whisper seeks internally in 30 s), never cutting mid-word; pass windows to native as `vv_audio_range` lists (`vv_stt_transcribe_ranges`) — no temp WAVs.
- [ ] Near-real-time mode uses the CPU backend while backgrounded on iOS (no Metal in background).
- [ ] Persist per-chunk results so a killed job resumes at the next chunk (FND-05).
- [ ] Carry previous-chunk text as prompt for continuity; detect and drop repetition loops/hallucinations.
- [ ] Optional near-real-time mode: transcribe chunks while recording continues (so results are ready at stop).
- [ ] Map chunk-local timestamps back to global recording time.

## Acceptance Criteria
- 2-hour recording transcribes with peak RAM stable (no growth) and resumes correctly after a forced kill.
- WER on stitched long-form within 1 pt of per-chunk WER on QA corpus.
- Real-time mode: transcript available ≤ 60 s after stopping a 30-min recording on flagship devices.
