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
| iOS | "Open in" / "Copy to Lumen" | `CFBundleDocumentTypes` (`public.audio` + listed UTIs) → `openURLContexts` via `FlutterSceneLifeCycleDelegate` → copied into `tmp/shared_audio` |
| iOS | Share extension | `ios/ShareExtension/` copies into the App Group inbox `group.<app id>/Inbox/Audio`, drained by the app on the next `takePendingShares`. The `ShareExtension` target is wired in `Runner.xcodeproj` (AUD-14): bundle id `<app id>.ShareExtension`, iOS 16, embedded in Runner, App Group `group.<app id>` on Runner and the extension (`$(APP_BUNDLE_IDENTIFIER)` per flavor). `tools/ci/check_ios_share_extension.sh` asserts this statically. See "iOS Share extension: App Group and signing" below. |

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

## iOS Share extension: App Group and signing

The extension cannot reliably open the host app and the audio must reach it,
so the hand-over is a file copy through an App Group container
(`group.<app id>/Inbox/Audio`). The extension has no network, microphone or
background capability and logs nothing.

| Fact | Status |
|---|---|
| Apple's [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios) table lists App Groups for the free Apple Developer (Personal Team) account as well as the paid programs | **Verified** (Apple doc) |
| Personal Team limits: 10 App IDs, 3 devices, 3 apps per device, profiles expire after 7 days ([account overview](https://developer.apple.com/help/account/get-started/about-your-developer-account)) | **Verified** (Apple doc) |
| Xcode automatic signing really provisions the App Group and the extension on a Personal Team device, and the App ID count (Runner, LumenWidgets, ShareExtension, two flavors) stays within the limit | **Unverified** — device rows in `docs/test-plans/device/AUD-14.md` |
| The simulator/unsigned CI build ignores entitlements, so signing is only exercised on a device | Verified by construction (`--no-codesign`) |

Without the App Group there is no equivalent hand-over design, so the
extension needs it. **Trade-off / fallback** if Personal Team signing fails on
a device: the app is still importable through "Open in / Copy to Lumen"
(`CFBundleDocumentTypes` + `openURLContexts`) and the Record-tab file picker,
neither of which needs an App Group. To build for such a device, remove the
`com.apple.security.application-groups` key from `Runner.entitlements` and the
ShareExtension target from the Embed phase locally (do not commit); the
paid-account/TestFlight builds keep the extension.
