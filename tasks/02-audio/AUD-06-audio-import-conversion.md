# AUD-06 — Audio File Import & Format Conversion

**Workstream:** Audio | **Phase:** 2 | **Size:** M | **Depends on:** AUD-01, FND-05, SEC-09 | **Source:** Gap (users will want to process existing recordings / voice memos)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-pipeline-orchestrator, vv-flutter-architecture, vv-local-database, vv-testing

## Goal
Process audio the user recorded elsewhere (e.g. Voice Memos, a dictaphone, a meeting recording they are entitled to) through the same pipeline. The app does not offer, market or special-case importing from call-recorder apps.

## Scope
- [x] Import via file picker and OS share sheet / "Open in" (iOS share extension, Android `ACTION_SEND` intent filter). (iOS share-extension sources + App Group inbox drain are in; adding the extension *target* to the Xcode project → AUD-10.)
- [x] Decode m4a/AAC, mp3, wav, ogg/opus, flac using native decoders (AVFoundation / MediaCodec) — avoid bundling full ffmpeg (size).
- [x] Resample to 16 kHz mono PCM; write into the same chunked layout as AUD-01.
- [x] Extract original creation date for filename templates.
- [x] Before processing an import, require the user to confirm: "I have the right to process this recording and everyone in it consented to being recorded" (SEC-09); store `import_attested_at` on the recording.

## Acceptance Criteria
- Per-platform format table in `docs/` (iOS: m4a/AAC, mp3, wav, flac, caf; Android: those + ogg/opus) — each listed format imports and transcribes on its platform; unsupported formats show a clear message.
- iOS share-extension import via App Group container works end-to-end.
- A 1-hour m4a imports in < 30 s on a mid-range device.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-06-audio-import · **Date:** 2026-10-14
- **Summary:** Pigeon `AudioImportHostApi` (`app/pigeons/audio_import_api.dart`) with native
  decoders only: iOS `AVAssetReader` (16 kHz mono PCM16 output settings) and Android
  `MediaExtractor` + `MediaCodec` (PCM16 at codec rate; Dart `PcmConverter` in `Isolate.run`).
  `AudioImportService` copies the source into app storage, refuses formats the platform cannot
  decode (`ImportFormats` table), decodes, writes chunks through AUD-01's `RecordingChunkWriter`
  (`source = imported`, `import_attested_at`, `created_at` = file recording date › shared-file date
  › now), cleans up, and queues the FND-05 pipeline. UI: Record tab **Import audio file** action
  (`file_selector`), the mandatory attestation dialog (Import disabled until ticked), outcome
  snackbars, and `SharedAudioImportListener` for shared files. Android `ACTION_SEND`/
  `SEND_MULTIPLE`/`VIEW` intent filters (copy immediately); iOS `CFBundleDocumentTypes` "Open in"
  via `FlutterSceneLifeCycleDelegate` + App Group inbox drain; share-extension sources in
  `app/ios/ShareExtension/`. Format table: `docs/audio-import.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [AUD-06/AC1]; artifact: docs/audio-import.md; device: docs/test-plans/device/AUD-06.md
  - AC2: ⏳ test: [AUD-06/AC2]; device: docs/test-plans/device/AUD-06.md
  - AC3: ⏳ device: docs/test-plans/device/AUD-06.md
- **Decisions:** no ADR (no technology choice beyond the skill's prescribed native decoders).
  PRODUCT-DECISIONs: imports are queued in normal order (not "process now"); the private source
  copy is deleted after decoding (only the 16 kHz chunks are kept); `created_at` uses the file's
  recording date; CAF/AIFF shown as unsupported on Android (see AC note below).
- **AC note for the user:** AC1 lists CAF for Android ("those + ogg/opus"); Android's
  `MediaExtractor` has no CAF extractor, so with native decoders only CAF shows the clear
  "can’t be imported" message on Android. Proposed AC clarification; the AC text is unchanged.
- **Not compiled here:** no Xcode / Android SDK on this machine — the Kotlin and Swift code
  (and the hand-edited `project.pbxproj` entries for the two new Runner Swift files) need the CI
  build / a device run. Host perf: the Dart resampler converts 60 s of 44.1 kHz stereo in ~0.3 s
  (JIT, M-series Mac) ⇒ ~20 s/hour before decoding — AC3 is tight on Android and must be measured.
- **Stacking:** based on origin/main (AUD-01, FND-05, SEC-09 in `review`).
- **Follow-ups:** AUD-10 (proposed).

## Follow-ups
- **AUD-10 (proposed): iOS share-extension target wiring** — add `ios/ShareExtension/` as an app
  extension target in `Runner.xcodeproj` (bundle id `$(APP_BUNDLE_IDENTIFIER).ShareExtension` per
  flavor, deployment target iOS 16, embed in Runner via "Embed Foundation Extensions"), add the App
  Group `group.<app id>` entitlement to Runner and the extension (register both in the developer
  portal / provisioning profiles), and run the AUD-06 AC2 device row. Needs Xcode + signing.
