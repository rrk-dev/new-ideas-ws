# STT-06 — Transcript Viewer & Editor

**Workstream:** STT | **Phase:** 2–3 | **Size:** M | **Depends on:** STT-03, FND-04 | **Source:** Gap (users must correct STT errors before extraction)
**Status:** review
**Skills:** vv-task-workflow, vv-whisper-stt, vv-flutter-architecture, vv-local-database, vv-pipeline-orchestrator, vv-testing

## Goal
Users can review, play back and correct transcripts before (re)running extraction.

## Scope
- [x] Segment list with timestamps and speaker labels; tap to play audio from that point.
- [x] Highlight current segment during playback (karaoke-style).
- [x] Inline text editing; low-confidence words highlighted.
- [x] Find & replace (e.g., fix a misheard name everywhere).
- [x] "Re-extract" action after edits (FND-05 re-run step).

## Acceptance Criteria
- User markers (AUD-08) appear at the correct positions in the transcript view.
- Editing persists and is used by subsequent extraction runs.
- Playback seek accuracy within 250 ms of segment start.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-06-transcript-viewer-editor (base origin/main; not stacked) · **Date:** 2026-10-14
- **Summary:** Transcript screen `app/lib/features/transcription/presentation/transcript_screen.dart`
  (route `/library/recordings/:id/transcript`, linked from the recording status screen): segment
  list with speaker chips (display names from `speakers`), timestamps, low-confidence words
  (p < 0.5 from `tokens_json`) underlined wavy, current-segment highlight from the player
  position, tap-to-play, inline edit (keeps the first `original_text`, sets `transcripts.edited`),
  find & replace scoped to the transcript (`TranscriptsRepository.editSegments`, one transaction,
  foreign segment ⇒ rollback), user/gap/call markers interleaved at their timeline positions
  (consent markers hidden), "Re-extract with edits" → `PipelineClient.rerun(job, extract)`.
  Domain: `transcript_view.dart` (interleave, highlight index, confidence ranges, find/replace),
  `playback_timeline.dart` (recording ms ↔ stream position across chunks with pauses),
  `transcript_player.dart`. Data: `recording_audio_source.dart` (`ChunkPcmReader` seam for SEC-01
  encrypted chunks, `VirtualWav` = header + concatenated chunk PCM, `RecordingAudioSource extends
  StreamAudioSource`), `just_audio_transcript_player.dart`. New dependency `just_audio 0.10.6`
  (exact; review rows in `docs/privacy-audit.md`): its stream sources go through a loopback-only
  proxy, so Android allows cleartext for `127.0.0.1` only (`res/xml/network_security_config.xml`)
  and iOS sets `NSAllowsLocalNetworking` (no arbitrary loads). l10n strings in `app_en.arb`;
  accessibility row `Transcript` in `test/widget/accessibility_test.dart`; golden
  `transcript_screen_*` (new) and `recording_status_screen_*` (changed: adds the "View and edit
  transcript" row below the status card).
- **Gates (2026-10-14, macOS host):** `dart format` clean, `flutter analyze` 0 issues, `dart analyze
  --fatal-infos` 0, `flutter test` all passed (813 + new), `pytest tools/ci/tests` 66 passed,
  `check_recording_policy` OK, `check_egress` OK, `check_codegen` clean after commit, goldens
  regenerated on Linux via `tools/ci/update_goldens.sh` (podman).
- **Acceptance evidence:**
  - AC1: ✅ test: [STT-06/AC1]
  - AC2: ✅ test: [STT-06/AC2]
  - AC3: ⏳ test: [STT-06/AC3]; device: docs/test-plans/device/STT-06.md
- **Decisions:** none (just_audio is the player the `vv-whisper-stt` skill prescribes; dependency
  review in `docs/privacy-audit.md`).
- **Follow-ups:** STT-08 (see below).

## Follow-ups
- STT-08 (proposed): `ChunkPcmReader` for the `vvenc` codec once SEC-01 chooses app-level
  encryption (decrypt-on-read in `RecordingAudioSource`, no plaintext temp files); speaker rename
  from the transcript chip (STT-05 owns speakers).
- just_audio marks `StreamAudioSource` `@experimental`: re-verify on every upgrade.

