# Privacy manifest and store privacy declarations (SEC-06)

Engineering record for `PrivacyInfo.xcprivacy`, the App Store privacy label
and the Play Data Safety form. `tools/ci/check_store_privacy.sh` enforces the
checkable parts (CI `static` job, pytest `[SEC-06/AC1]`).

## Manifests
| Manifest | Scope |
|---|---|
| `app/ios/Runner/PrivacyInfo.xcprivacy` | App target (in the Runner Resources phase) |
| `packages/vv_native/ios/PrivacyInfo.xcprivacy` | `vv_native` pod (whisper.cpp / llama.cpp), bundled by the podspec as `vv_native_privacy` |

Both declare `NSPrivacyTracking = false`, no tracking domains, and no
collected data types.

## Required-reason APIs (app target)
| Category | Reason | Where the app uses it |
|---|---|---|
| File timestamp | `C617.1` | Files inside the app container: recordings, models (`AudioImportHostApiImpl`, native model mapping) |
| File timestamp | `3B52.1` | Creation date of an audio file the user picks to import (`AudioImportHostApiImpl.swift`) |
| Disk space | `E174.1` | Free space checked before writing a recording or model (`StorageInfoPlugin`, `ModelDownloadPlugin`) |
| User defaults | `CA92.1` | Model-download bookkeeping (`ModelDownloadPlugin`), this app only |

System boot time and active keyboard APIs are not used by first-party code.
The CI check scans first-party Swift/ObjC for those APIs and fails if a use is
not declared.

## Third-party SDKs and plugins
There are no tracking, analytics, ads or crash SDKs (`docs/privacy-audit.md`,
`tools/ci/check_packages.sh`). Flutter and the Flutter plugins ship their own
manifests inside their pods; Xcode merges them into the app's privacy report.
Before each release (`docs/release-checklist.md`):
1. Archive the iOS build, then Product → Archive → Generate Privacy Report.
2. Compare the report with the table above and with each pod's manifest.
3. Attach the report PDF to the release record. ⏳ Human step on a Mac with
   the signing identity.

## App Privacy ("nutrition label")
Answer **Data Not Collected**. Why it is true:
- No account, no analytics, no ads, no crash upload (`docs/crash-triage.md`).
- The only network use is model download from our host/mirror; the request
  carries no user content (`docs/privacy-audit.md`, egress test SEC-02).
- Purchases run inside StoreKit; Apple handles them.

## Google Play Data Safety
Answer **No data collected** and **No data shared**; "Data is encrypted in
transit" is yes (https only) and "You can request data deletion" is yes
(Settings → Delete all data; nothing is stored off-device).
Permissions requested (see `docs/play-console/fgs-declaration.md`):
`RECORD_AUDIO`, foreground-service microphone/dataSync, notifications,
internet and network state. No advertising ID, location, contacts, SMS, camera
or phone-state/call-log permissions (also enforced by SEC-09).

## Usage-description strings and background modes
| Item | Value | Justification for reviewers |
|---|---|---|
| `NSMicrophoneUsageDescription` | "VaultVoice uses the microphone only to record notes you start. Audio is processed on this device and never uploaded." | Core feature; the OS prompt follows an in-app explanation (APP-01) |
| `NSFaceIDUsageDescription` | "Face ID unlocks your recordings and notes when the app lock is on." | Optional app lock |
| `UIBackgroundModes: audio` | — | A recording the user started keeps running when they switch apps; the indicator stays visible and the OS shows the recording status |
| `UIBackgroundModes: processing` | — | Transcription/extraction of the user's recordings continues in a BGProcessingTask; no network |
