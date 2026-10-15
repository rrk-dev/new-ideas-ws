# Device verification — STT-06 Transcript Viewer & Editor

Host tests cover the logic (`[STT-06/AC1..3]` in `app/test/unit/transcription/` and
`app/test/widget/transcript_screen_test.dart`); these rows confirm real playback through
just_audio (AVPlayer / ExoPlayer via the loopback `StreamAudioSource` proxy) on devices.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-06/AC1] | 1. Record ~2 min, tap **Mark** at ~0:40 and ~1:30. 2. Let the job finish. 3. Library → recording → *View and edit transcript*. | Both markers appear as flag rows between the segments around 0:40 and 1:30 (marker time shown on the right matches the tap time ±1 s). | iPhone 11 | iOS 18.x | ⏳ | | |
| [STT-06/AC1] | Same as above. | Same as above. | Pixel 7 | Android 15 | ⏳ | | |
| [STT-06/AC3] | 1. Open the transcript of a recording with ≥ 3 chunks and one pause. 2. Tap a segment in the 2nd chunk, then one after the pause. 3. Screen-record with audio; compare the first audible word with the segment's start time (Audacity on the exported recording or the on-screen position counter). | Playback starts within 250 ms of each segment's start; the tapped segment is highlighted while it plays and the highlight follows playback. | iPhone 11 | iOS 18.x | ⏳ | | |
| [STT-06/AC3] | Same as above. | Same as above. | Pixel 7 | Android 15 | ⏳ | | |

## Notes / evidence
Screen recordings under `docs/test-plans/device/evidence/STT-06/`. Android: confirm no
`Cleartext HTTP traffic not permitted` error in logcat (network security config allows only
127.0.0.1).
