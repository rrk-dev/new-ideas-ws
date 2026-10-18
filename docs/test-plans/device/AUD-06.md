# Device verification — AUD-06 Audio File Import & Format Conversion

Authored without devices, Xcode or an Android SDK: the native decoders
(`ios/Runner/AudioImportHostApiImpl.swift`, `android/.../audioimport/AudioImportHostApiImpl.kt`)
have not been compiled or run here; the Dart import path ran against fakes
(`app/test/unit/recording/audio_import_test.dart`, `app/test/widget/audio_import_flow_test.dart`).
Fill Device/OS/Result/Date/Tester only after running.

Setup: dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`). Test
files (no personal recordings): create one 60 s speech clip per format from the same source, e.g.
`ffmpeg -i speech.wav -ar 44100 -ac 2 clip.m4a` / `.mp3` / `.flac` / `.wav`, `afconvert -f caff -d
LEI16 speech.wav clip.caf`, `ffmpeg -i speech.wav -c:a libopus clip.opus` and `-c:a libvorbis
clip.ogg`, plus a 1-hour m4a (`ffmpeg -stream_loop 59 -i clip.m4a -c copy hour.m4a`). Transcription
needs STT models installed (MDL-02/MDL-04).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-06/AC1] | iOS: Record tab → Import audio file → pick each of clip.m4a, .mp3, .wav, .flac, .caf, .aiff; tick the attestation; Import. Then open each recording. | Each: "Imported. Processing has been queued."; recording appears with ~60 s duration and its transcript matches the speech; chunks are 16 kHz mono (`soxi`). | iPhone (oldest in matrix) | iOS 16+ | | | |
| [AUD-06/AC1] | iOS: import clip.opus and clip.ogg. | "Ogg/Opus files can’t be imported on this device."; no attestation asked; nothing added. | iPhone | iOS 16+ | | | |
| [AUD-06/AC1] | Android: import clip.m4a, .mp3, .wav, .flac, .ogg, .opus. | Each imports and transcribes as above. | Pixel + Samsung | Android 8 (API 26) and 14+ | | | |
| [AUD-06/AC1] | Android: import clip.caf. | "CAF files can’t be imported on this device." | Android phone | API 26+ | | | |
| [AUD-06/AC1] | Both: import a clip, untick/cancel the attestation dialog. | Nothing imported; the private copy is gone (`run-as … ls cache/shared_audio` / Files container). | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-06/AC1] | Android: share clip.m4a from Files / a voice recorder app → Lumen; also "Open with" Lumen. | App opens, attestation shown, import succeeds; `created_at` = the clip's recording date (check the note filename / recording title date). | Android phone | API 26+ | | | |
| [AUD-06/AC1] | iOS: Files → clip.m4a → Share → "Copy to Lumen" / "Open in Lumen". | App opens, attestation shown, import succeeds. | iPhone | iOS 16+ | | | |
| [AUD-06/AC2] | Target wired in AUD-14 (row also in `AUD-14.md`). iOS: Voice Memos → share a memo → Lumen extension; then open Lumen. | Extension finishes immediately; on opening the app the attestation for the memo is shown; import succeeds; the App Group `Inbox/Audio` is empty afterwards. | iPhone | iOS 16+ | | | |
| [AUD-06/AC3] | Mid-range device: import hour.m4a; time from tapping Import to "Imported…" (screen recording). | < 30 s; UI stays responsive (no ANR / watchdog kill). | Mid-range Android (e.g. Pixel 6a / Galaxy A54) + iPhone 12/13 | API 31+ / iOS 16+ | | | |

## Notes / evidence
