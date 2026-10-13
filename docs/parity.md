# iOS / Android parity

Feature checklist for VaultVoice. Every row is a user-facing behavior or a platform
mechanism the tasks require. Update the row when the owning task's Completion Notes
change the behavior.

**Beta review: not signed.** REL-04 must complete the sign-off at the bottom before
an external TestFlight or Play test opens. This file is the checklist that review
uses. It was written from the task specs and skills on 2026-10-12, before the app
existed, so it is a contract, not a test result.

Legend: **Yes** ships with the same user-visible result. **Diff** ships on both
platforms with the difference in the last column. **No** does not ship on that
platform. **Lab** is a test-coverage gap, not a product gap.

## Capture and import

| Feature | iOS | Android | Difference | Task |
|---|---|---|---|---|
| Record 16 kHz mono WAV, only after an explicit tap | Yes | Yes | Same chunk layout | AUD-01, SEC-09 |
| Pause and resume | Yes | Yes | Resume after a call is always a new tap | AUD-01, SEC-09 |
| Auto-gain and level meter | Yes | Yes | — | AUD-02 |
| Silence detection / VAD | Yes | Yes | — | AUD-03 |
| Keep recording while locked | Diff | Diff | iOS: `audio` background mode. Android: microphone foreground service and a non-dismissible notification | AUD-04, AUD-05 |
| Route and session interruptions (alarm, Bluetooth) | Diff | Diff | Different session APIs. Capture pauses; it does not silently keep a call or a ducked session | AUD-04, AUD-05 |
| Import m4a/AAC, mp3, wav, flac | Yes | Yes | — | AUD-06 |
| Import CAF | Yes | No | Apple container. Not a promised Android format | AUD-06 |
| Import Ogg/Opus | No | Yes | iOS AVFoundation does not decode it. Show "unsupported" on iOS. Do not bundle ffmpeg. A libogg/libopus bridge would be a separate ADR | AUD-06 |
| Import from the share sheet | Diff | Diff | iOS: share extension copies into the App Group, then the app imports. Android: `ACTION_SEND` / `ACTION_VIEW`, copy via `ContentResolver` immediately | AUD-06 |
| Import rights attestation | Yes | Yes | Same confirmation, stored as `import_attested_at` | AUD-06, SEC-09 |
| Recover a recording after a crash | Yes | Yes | — | AUD-07 |
| Recording screen (timer, meter, markers) | Yes | Yes | — | AUD-08 |
| Home-screen widget | Diff | Diff | Both are a deliberate tap. Neither may start the microphone from a headless context | AUD-08, SEC-09 |
| Control Center / Lock Screen control | Yes | No | iOS only. `openAppWhenRun` so the in-app tap still starts the mic | AUD-08 |
| Quick settings tile | No | Yes | Android only. Same rule: the tile is a deliberate tap, not an automation | AUD-08 |
| Visible recording indicator | Diff | Diff | iOS orange dot + Live Activity when supported. Android privacy indicator + ongoing notification. No discreet mode on either | SEC-09 |
| Call guard (cellular and VoIP) | Diff | Diff | Same outcome: refuse start, stop within 500 ms, discard post-start buffered audio, stay paused until Resume. iOS uses `CXCallObserver` (no extra permission). Android uses `AudioManager` mode and `isClientSilenced` — never `READ_PHONE_STATE` | SEC-09 |
| Hourly reminder and max duration | Yes | Yes | Default max 4 h, configurable up to 8 h | SEC-09 |

## Transcription and extraction

| Feature | iOS | Android | Difference | Task |
|---|---|---|---|---|
| On-device Whisper | Diff | Diff | iOS: Metal, optional Core ML encoder (STT-01 spike). Android: Vulkan and/or OpenCL, CPU if init fails. NNAPI is out of scope | STT-01, STT-02 |
| Long-form chunked transcription | Diff | Diff | iOS background work does not submit Metal. The job switches to CPU at a chunk boundary or pauses. Android may keep the GPU under the processing foreground service, subject to the thermal pause | STT-04, FND-08 |
| Speaker diarization, no voiceprints | Yes | Yes | — | STT-05 |
| Transcript viewer and editor | Yes | Yes | — | STT-06 |
| Other languages / model variants | Yes | Yes | — | STT-07 |
| On-device LLM | Diff | Diff | iOS Metal. Android Vulkan/OpenCL with CPU fallback | LLM-02, LLM-03 |
| Device memory tiers | Yes | Yes | Low &lt; 5 GB (iPhone 11, VV-AND-4G), Mid 5–7 GB, High ≥ 7 GB. Same defaults | LLM-07 |
| Structured (grammar-constrained) output | Yes | Yes | — | LLM-05 |
| Map-reduce for long transcripts | Yes | Yes | — | LLM-06 |
| STT and LLM not resident together | Yes | Yes | — | LLM-07 |

## Models, notes, and the vault

| Feature | iOS | Android | Difference | Task |
|---|---|---|---|---|
| Signed model catalog and download | Diff | Diff | Same manifest. iOS background `URLSession`; Android WorkManager. No other network | MDL-01, MDL-02 |
| Model management screen | Yes | Yes | — | MDL-03 |
| Offline sideload | Yes | Yes | — | MDL-04 |
| Meeting, Warranty, Engineering profiles | Yes | Yes | — | PRF-03, PRF-04, PRF-05 |
| Auto profile classification | Yes | Yes | — | PRF-06 |
| Custom profile editor (Pro) | Yes | Yes | — | PRF-07 |
| Profile and template import/export | Yes | Yes | — | PRF-08 |
| Markdown templates | Yes | Yes | — | EXP-01 |
| Filename templates | Yes | Yes | — | EXP-02 |
| User-chosen vault folder | Diff | Diff | Android Storage Access Framework. iOS security-scoped bookmarks. Same routing rules on top | EXP-03, EXP-04, EXP-05 |
| Failed-write outbox | Yes | Yes | — | EXP-06 |
| Template editor (Pro) | Yes | Yes | — | EXP-07 |
| Share sheet, Logseq, plain Markdown | Yes | Yes | — | EXP-08 |

## App, purchase, and privacy

| Feature | iOS | Android | Difference | Task |
|---|---|---|---|---|
| Onboarding and just-in-time mic permission | Diff | Diff | Same priming screen. System dialogs differ. Permission is not requested at launch | APP-01, SEC-09 |
| Library and full-text search | Yes | Yes | — | APP-02 |
| Settings | Yes | Yes | MDM-locked rows are read-only on both | APP-03, LIC-04 |
| Processing status and notifications | Diff | Diff | Same job states. System notification UI differs | APP-04 |
| Review before export | Yes | Yes | — | APP-05 |
| Accessibility and localization | Yes | Yes | — | APP-06 |
| Tablet layout | Lab | No | One iPad is in the matrix. No Android tablet | QA-05 |
| Free / Pro gating | Yes | Yes | — | LIC-01 |
| In-app purchase and offline grace | Diff | Diff | StoreKit 2 versus Play Billing. Verification stays on device unless LIC-02's ADR says otherwise | LIC-02 |
| Enterprise license file | Yes | Yes | — | LIC-03 |
| MDM managed configuration | Diff | Diff | iOS managed app configuration. Android `app_restrictions.xml`. Policies can only make recording stricter. No remote start | LIC-04 |
| Encryption at rest | Diff | Diff | iOS Data Protection. Android credential-encrypted storage. App-level `vvenc` only if SEC-01's ADR requires it | SEC-01 |
| Network egress allowlist | Yes | Yes | One gateway. Store billing stays inside the OS frameworks | SEC-02 |
| App lock (biometrics) | Diff | Diff | Face ID / Touch ID versus `BiometricPrompt`. A widget/tile tap may start recording while content stays hidden | SEC-03 |
| Retention and secure deletion | Yes | Yes | — | SEC-04 |
| Per-recording consent confirmation | Yes | Yes | — | SEC-07 |
| Local diagnostics, user-shared | Yes | Yes | No automatic upload | FND-07, REL-02 |
| Long processing after the user leaves | Diff | Diff | iOS `BGProcessingTask` (CPU, system-scheduled, often on power). Android foreground service `dataSync` (API ≤ 34) or `mediaProcessing` (API 35+), 6 h / 24 h, plus WorkManager | FND-08 |
| GPU while the app is backgrounded | No | Diff | iOS: do not submit Metal in the background. Android: the processing service may keep the GPU until thermal policy pauses the job | FND-08 |

## Ogg/Opus on iOS

This is the difference the beta review has to look at on a phone, not only in the table.

1. On Android, an `.ogg` / Opus file imports, resamples to 16 kHz mono, and enters the same pipeline as a recording.
2. On iOS, the same file is rejected with an explicit unsupported-format message. Supported iOS imports are m4a/AAC, mp3, wav, flac, and caf.
3. The store listing and the import screen must not imply that every Android format works on iOS.

Owning task: AUD-06. A future ADR could vendor libogg/libopus (BSD) into the bridge. Until that ADR is Accepted, the gap stays.

## Beta review

Complete this before the external beta (REL-04). Do not tick from a doc reading alone;
confirm the Ogg/Opus row and the call-guard row on one in-lab iPhone and one in-lab
Android phone.

| Check | Reviewer | Date | Result |
|---|---|---|---|
| Every row still matches the build going to beta | | | |
| iOS rejects Ogg/Opus with a clear message; Android imports it | | | |
| Call guard: start refused during a call; no auto-resume after (both platforms) | | | |
| Vault folder: SAF on Android, bookmark on iOS, both writable after reboot | | | |
| No cloud-farm run was used as evidence for a content feature | | | |
