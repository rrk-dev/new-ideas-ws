# AUD-06 — Audio File Import & Format Conversion

**Workstream:** Audio | **Phase:** 2 | **Size:** M | **Depends on:** AUD-01, FND-05, SEC-09 | **Source:** Gap (users will want to process existing recordings / voice memos)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-pipeline-orchestrator, vv-flutter-architecture, vv-local-database, vv-testing

## Goal
Process audio the user recorded elsewhere (e.g. Voice Memos, a dictaphone, a meeting recording they are entitled to) through the same pipeline. The app does not offer, market or special-case importing from call-recorder apps.

## Scope
- [ ] Import via file picker and OS share sheet / "Open in" (iOS share extension, Android `ACTION_SEND` intent filter).
- [ ] Decode m4a/AAC, mp3, wav, ogg/opus, flac using native decoders (AVFoundation / MediaCodec) — avoid bundling full ffmpeg (size).
- [ ] Resample to 16 kHz mono PCM; write into the same chunked layout as AUD-01.
- [ ] Extract original creation date for filename templates.
- [ ] Before processing an import, require the user to confirm: "I have the right to process this recording and everyone in it consented to being recorded" (SEC-09); store `import_attested_at` on the recording.

## Acceptance Criteria
- Per-platform format table in `docs/` (iOS: m4a/AAC, mp3, wav, flac, caf; Android: those + ogg/opus) — each listed format imports and transcribes on its platform; unsupported formats show a clear message.
- iOS share-extension import via App Group container works end-to-end.
- A 1-hour m4a imports in < 30 s on a mid-range device.
