# Stress and edge-case test plan (QA-04)

Owner: Quality. Run before each phase gate and before launch on the lab devices in
[device-matrix.md](../device-matrix.md). Host-automatable cases run in CI as
`[QA-04/AC1]` tests (`app/test/stress/pipeline_stress_test.dart`). Everything else is a
row in [device/QA-04.md](device/QA-04.md). Rows start ⏳ and become `PASS` only when a
person runs them on a device.

**Launch rule:** zero open data-loss bugs. A data-loss bug is any case where audio
already captured, a committed transcript or a finished note is lost, duplicated or
corrupted. Any such failure blocks launch whatever its other severity.

## Host-automated cases

| ID | Case | Test | Pass condition |
|---|---|---|---|
| S-01 | 50 recordings queued, processed back to back | `50 queued recordings…` | All jobs `done`, 50 notes, 50 export rows, STT called once per chunk |
| S-02 | 3 h recording (360 × 30 s chunks), app killed mid-transcription | `a 3 hour recording…` | Relaunch resumes at the checkpoint, committed chunks are not transcribed again, 360 segments, one note |
| S-03 | App killed in the middle of a 20-job queue | `a kill in the middle…` | Every job `done`, each note exported once |
| S-04 | Low storage while exporting | `low storage during export…` | Transcript kept, no partial note, retry completes |
| S-05 | Vault permission revoked mid-queue | `vault permission revoked…` | Jobs park (waiting/failed), nothing written, finish after access returns |

## Device cases

"All" means every `In lab` unit.

### Long and queued work

| ID | Case | Steps | Pass condition | Devices |
|---|---|---|---|---|
| D-01 | 3 h recording | Tap Record, leave the phone on a desk with a looped talk for 3 h, screen locked | One continuous recording, chunks contiguous, indicator visible, file size within 5% of 3 h of 16 kHz mono WAV | VV-IOS-11, VV-AND-4G |
| D-02 | 50 queued | Import 50 short clips, enqueue all, plug in | All 50 reach `done`; no crash; memory stays under the tier cap | VV-IOS-16, VV-AND-7 |
| D-03 | Back-to-back | Record, stop, start another within 2 s, repeat 10 times | 10 separate recordings, none empty | All |

### Low storage (< 500 MB free)

| ID | Case | Steps | Pass condition | Devices |
|---|---|---|---|---|
| D-04 | During recording | Fill storage until < 500 MB, record | Warning before capture; if the disk fills, capture stops cleanly and keeps everything recorded so far | VV-IOS-11, VV-AND-4G |
| D-05 | During model download | Fill storage, start a download | Download refuses or stops with a clear message; no partial model is installed | VV-IOS-11, VV-AND-4G |
| D-06 | During export | Fill the vault volume, export | Note is not half written; job waiting/failed with a retry; after freeing space Retry succeeds | VV-IOS-11, VV-AND-4G |

### Interruptions

| ID | Case | Steps | Pass condition | Devices |
|---|---|---|---|---|
| D-07 | Alarm or timer fires while recording | Set an alarm for 1 min, record through it | Audio before the alarm is kept; capture pauses or continues per policy; never auto-resumes after a call | All |
| D-08 | Bluetooth connect/disconnect | Record, connect then disconnect AirPods or a headset | Capture continues or pauses cleanly; no unmarked gap over 1 s; no crash | VV-IOS-16, VV-AND-PIX |
| D-09 | App kill | Swipe-kill the app mid-recording, relaunch | Crash recovery offers the partial recording; audio up to the last chunk is playable | All |
| D-10 | Reboot | Reboot mid-recording and mid-processing, relaunch | Recording recovered; queued jobs resume from their checkpoint | All |
| D-11 | Low Power Mode / Battery Saver | Enable during a processing job | Job continues or pauses with a visible reason; resumes when disabled; no loss | All |
| D-12 | Airplane mode | Enable before and during record, process and export | Everything works offline; the only network use is model download | All |

### Calls (SEC-09)

Run each row with the app in foreground, background and locked (three runs per row).
Pass condition for all rows: **no call audio is captured and recording never
auto-resumes**; a visible notice tells the user why it stopped.

| ID | Call type | Steps | Devices |
|---|---|---|---|
| D-13 | Cellular incoming | Start recording, call the phone, answer, hang up | VV-IOS-16, VV-AND-PIX |
| D-14 | Cellular outgoing | Start recording, place a call, hang up | VV-IOS-16, VV-AND-PIX |
| D-15 | VoIP incoming | Start recording, receive a WhatsApp or FaceTime call, answer, hang up | VV-IOS-16, VV-AND-PIX |
| D-16 | VoIP outgoing | Start recording, place a VoIP call, hang up | VV-IOS-16, VV-AND-PIX |
| D-17 | Call declined or ignored | Start recording, let a call ring out | VV-IOS-16, VV-AND-PIX |

Inspect the saved audio: it must end at the moment the call began. Resume must need
a new user tap.

### Permission revocation

| ID | Case | Steps | Pass condition | Devices |
|---|---|---|---|---|
| D-18 | Mic revoked mid-recording | Revoke the mic in Settings while recording | Recording stops, audio so far is kept, a clear prompt explains how to re-enable | All |
| D-19 | Vault folder revoked | Revoke folder access (delete the folder, clear the SAF grant or move the vault) while jobs are queued | Jobs wait with a "choose a folder" action; nothing is lost; re-pick completes them | VV-IOS-16, VV-AND-PIX |

### Hostile audio

Use clips prepared by the tester (no real people; see `tools/bench/corpus`).

| ID | Case | Pass condition | Devices |
|---|---|---|---|
| D-20 | Silence only (10 min) | No hallucinated transcript; a "no speech detected" result; no crash | All |
| D-21 | Music only | No fabricated action items; extraction is empty or flagged | VV-IOS-16, VV-AND-7 |
| D-22 | Non-English (at least 3 languages, one non-Latin script) | Language handling per STT-03; no crash; no stuck job | VV-IOS-16, VV-AND-7 |
| D-23 | Very noisy audio (cafe, traffic, clipping) | Job completes; low confidence is flagged; no crash | VV-IOS-11, VV-AND-4G |

### OS upgrades

| ID | Case | Steps | Pass condition | Devices |
|---|---|---|---|---|
| D-24 | Upgrade with data | Install the previous release, create recordings and notes, update the OS to the next major, then update the app | DB migrates, models and recordings intact, vault grant still valid | One iPhone and one Android on the previous major, then upgraded |
| D-25 | Current and previous major | Run the smoke set (D-03, D-09, D-13, D-18) on the current and previous major iOS and Android | PASS on both | One iPhone, one Android |

## Reporting

Record failures as GitHub issues labelled `data-loss` (blocks launch) or `stress`.
Evidence goes under `docs/test-plans/device/evidence/QA-04/`. Re-run the whole matrix
after any change to recording, pipeline, storage or export code.
