# Audio import (AUD-06)

Users can process audio they recorded elsewhere (Voice Memos, a dictaphone, a meeting recording
they are entitled to). The app does not offer, market or special-case importing from call-recorder
apps. Every import requires the attestation *"I have the right to process this recording and
everyone in it consented to being recorded."* (SEC-09), stored as `recordings.import_attested_at`.

## Entry points
| Platform | Entry point | How |
|---|---|---|
| both | Record tab → **Import audio file** | `file_selector` system picker (Android `ACTION_OPEN_DOCUMENT` `audio/*`, iOS document picker `public.audio`, copy mode) |
| Android | Share sheet / "Open with" | `ACTION_SEND`, `ACTION_SEND_MULTIPLE`, `ACTION_VIEW` intent filters (`audio/*`, `application/ogg`) on `MainActivity`; the content URI is copied into `cacheDir/shared_audio` immediately (grants are temporary) |
| iOS | "Open in" / "Copy to VaultVoice" | `CFBundleDocumentTypes` (`public.audio` + listed UTIs) → `openURLContexts` via `FlutterSceneLifeCycleDelegate` → copied into `tmp/shared_audio` |
| iOS | Share extension | `ios/ShareExtension/` copies into the App Group inbox `group.<app id>/Inbox/Audio`, drained by the app on the next `takePendingShares`. **Target wiring (Xcode target, App Group entitlement on both targets, embedding) is follow-up AUD-10.** |

Nothing is decoded or processed before the user ticks the attestation; a cancelled import deletes
the private copy.

## Pipeline
1. Copy the source into `<appSupport>/vv/work/import_<id>/` (app storage first).
2. Decode natively — **no bundled ffmpeg** (size, licensing):
   iOS `AVAssetReader` + `AVAssetReaderTrackOutput` (linear PCM 16 kHz mono 16-bit settings —
   AVFoundation resamples and down-mixes); Android `MediaExtractor` + `MediaCodec` (PCM16 at the
   codec's rate; float output converted).
3. Android only: resample/down-mix to 16 kHz mono with the AUD-01 band-limited `PcmConverter`
   in a background isolate (`Isolate.run`).
4. Write 5-minute chunks through `RecordingChunkWriter` (same layout, codec seam and
   `audio_chunks` rows as a microphone recording), `source = imported`.
5. `created_at` = the file's recording date (iOS `AVAsset.creationDate`, Android
   `METADATA_KEY_DATE`), else the date the OS reported for the shared file, else the import time
   (filename templates use it).
6. Queue the recording in the FND-05 pipeline; delete the temporary files.

## Format table (AC1)
✅ = imports and transcribes; ❌ = shown as "… files can’t be imported on this device."
The table is checked against `ImportFormats.all` by `app/test/unit/recording/audio_import_test.dart`.

| Format | Extensions | iOS | Android |
|---|---|---|---|
| M4A/AAC | m4a, aac, mp4 | ✅ | ✅ |
| MP3 | mp3 | ✅ | ✅ |
| WAV | wav, wave | ✅ | ✅ |
| FLAC | flac | ✅ | ✅ |
| CAF | caf | ✅ | ❌ |
| AIFF | aif, aiff | ✅ | ❌ |
| Ogg/Opus | ogg, oga, opus | ❌ | ✅ |

Notes:
- iOS: AVFoundation has no Ogg demuxer, so Ogg/Opus/Vorbis are refused with a clear message
  (vendoring libogg/libopus into the bridge would need an ADR — not planned).
- Android: `MediaExtractor` has no CAF or AIFF extractor (platform supported-media-formats page).
  The task's AC lists CAF for Android as well ("those + ogg/opus"); with native decoders only this
  is not possible — CAF is an Apple container and shows the clear "can’t be imported" message.
  Flagged to the user as a proposed AC clarification.
- Unknown extensions are passed to the decoder; it decides (e.g. `.3gp`/`.amr` on Android).
