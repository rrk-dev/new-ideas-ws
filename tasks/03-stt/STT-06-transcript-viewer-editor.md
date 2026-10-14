# STT-06 — Transcript Viewer & Editor

**Workstream:** STT | **Phase:** 2–3 | **Size:** M | **Depends on:** STT-03, FND-04 | **Source:** Gap (users must correct STT errors before extraction)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-whisper-stt, vv-flutter-architecture, vv-local-database, vv-pipeline-orchestrator, vv-testing

## Goal
Users can review, play back and correct transcripts before (re)running extraction.

## Scope
- [ ] Segment list with timestamps and speaker labels; tap to play audio from that point.
- [ ] Highlight current segment during playback (karaoke-style).
- [ ] Inline text editing; low-confidence words highlighted.
- [ ] Find & replace (e.g., fix a misheard name everywhere).
- [ ] "Re-extract" action after edits (FND-05 re-run step).

## Acceptance Criteria
- User markers (AUD-08) appear at the correct positions in the transcript view.
- Editing persists and is used by subsequent extraction runs.
- Playback seek accuracy within 250 ms of segment start.
