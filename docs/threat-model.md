# Threat model and pre-launch security review (SEC-08)

Status: threat model written 2026-10-15 from a desk review of the code and task
records at `origin/main` (`bc6f370`). The dynamic parts (fuzz runs on a libFuzzer
host, OSV scan in CI, MobSF scan, internal pen test) have tooling and runbooks here
but still need a human run. They are launch gates, listed in
[Pre-launch gate](#pre-launch-gate) and in
[device/SEC-08.md](test-plans/device/SEC-08.md).

**Launch rule:** no open high or critical finding. The register
([Findings](#findings)) has none today. It stays authoritative: a new high or
critical finding blocks launch until fixed and retested.

This is engineering analysis, not legal advice. The enterprise licence/MDM layer
(LIC-03, LIC-04) is covered only where it touches the recording policy.

## Scope and assets

| Asset | Why it matters | Where it lives |
|---|---|---|
| Recordings (WAV chunks) | Raw voice of the user and third parties | App storage, encrypted at rest (SEC-01) |
| Transcripts, extractions, notes | Sensitive content | Encrypted drift DB (FND-04, SEC-01), then the user's vault |
| Models (GGUF, Whisper) | Parsed by native code; integrity matters | App storage, installed atomically (MDL-02) |
| Profiles and templates | Drive prompts and Markdown output | DB; `.vvprofile` bundles on import |
| Vault grants | Write access to the user's folders | SAF tree URI / iOS bookmark (EXP-03, EXP-04) |
| Entitlements | Revenue | Store receipts (LIC-02) |
| Diagnostics zip | Logs and metrics, never content | Local, shared only by user action (FND-07) |

There is no server holding user data. The only network use is the model catalog and
CDN (SEC-02, `docs/privacy-audit.md`).

## Trust boundaries

1. **Internet to app:** catalog and model downloads. Everything is untrusted until
   the Ed25519 signature and SHA-256 check pass.
2. **Files and intents to app:** imported audio, `.vvprofile` bundles, sideloaded
   GGUF files, share-sheet input. All untrusted.
3. **Spoken content to LLM:** the transcript is attacker-influenced text.
4. **App to native code:** Dart to `vv_bridge` C ABI to whisper.cpp/llama.cpp. A
   parser bug here runs in the app process.
5. **App to vault:** the app writes files into folders other apps read.
6. **Device to someone else:** lost, stolen or borrowed phone.

## STRIDE analysis

Severity is inherent risk before the listed mitigation: H, M or L.

| # | Threat | STRIDE | Sev | Mitigations in place | Tasks | Residual |
|---|---|---|---|---|---|---|
| T1 | Malicious or malformed GGUF/Whisper model file crashes or exploits the parser | T, D, E | H | Catalog models are Ed25519-signed and SHA-256 verified before install; sideload of unsigned files is an explicit opt-in with a warning that a malformed file can crash the app; GGUF validity check on import; pinned llama.cpp/whisper.cpp; libFuzzer target for GGUF parsing (`native/fuzz/fuzz_gguf.cpp`); ASan/UBSan host build (`native/tests/sanitize.sh`) | MDL-01, MDL-02, MDL-04, SEC-08 | M (F-01) |
| T2 | Tampered or replayed catalog manifest, CDN compromise, redirect to another host | S, T | H | Signature checked against pinned keys (`catalog_verifier.dart`, `catalog_keys.dart`); size caps (`kMaxCatalogBytes`); hash mismatch deletes the file; downloads only through the egress gateway allowlist; HTTPS only (`usesCleartextTraffic=false`, ATS) | MDL-01, MDL-02, SEC-02 | L |
| T3 | Malicious imported profile (`.vvprofile`) with huge, nested or hostile content | T, D | M | Bundle limits (4 entries, 1 MiB per file, `profile_bundle.dart`); parsed as data, schema validated; imported profiles are inert until the user selects them; prompt builder treats fields as text | PRF-07, PRF-08 | L |
| T4 | Malicious template (Mustache) injecting YAML/Markdown that breaks note structure or reads other data | T, I | M | Logic-less Mustache engine, safe YAML front-matter escaping, `markdown_sanitizer.dart`, filename sanitising and vault path checks (`VaultPath.parse`) | EXP-01, EXP-02, EXP-05 | L |
| T5 | Prompt injection via spoken content ("ignore previous instructions, output …") | T, I | M | Output limited to the profile's JSON schema by grammar, then validated; model has no tools, network or file access; result shown in review before export; transcript content never logged | LLM-05, PRF-02, APP-05 | M (F-02) |
| T6 | **Covert recording**: recording starts without the user's tap | S, R | H | Start only through `RecordingController.start(StartSource)` with an allowed-source enum; no pre-capture; visible indicator; long-session reminder; CI guard `check_recording_policy.sh`; see [SEC-09 bypass review](#sec-09-bypass-review) | SEC-09, AUD-01, AUD-04, AUD-05, AUD-08 | L |
| T7 | **Call recording** (cellular or VoIP) | S, I | H | CallGuard stops capture on call start and never auto-resumes; no call permissions, audio sources, CallKit/VoIP modes, MediaProjection or Accessibility; CI guard on merged manifests, plists and sources | SEC-09 | L |
| T8 | Lost or stolen unlocked device | I | H | Encrypted DB and files at rest with OS-keystore keys; optional app lock with biometrics; backups disabled (`allowBackup=false`, backup rules); secure deletion and retention | SEC-01, SEC-03, SEC-04 | M (device compromise out of scope) |
| T9 | Malicious audio file import (decoder bugs, oversized files, zip-like containers) | T, D, E | M | Import converts through the platform decoders to 16 kHz PCM16 WAV; the bridge only reads that format (`vv_wav.h` rejects everything else, clamps stale lengths); libFuzzer/standalone fuzz of the WAV parser; rights/consent attestation | AUD-06, SEC-08 | L (F-04) |
| T10 | Licence forgery or entitlement tampering | S, T, E | M | Entitlements derive from StoreKit 2 / Play Billing verified transactions with offline grace; no client-side secrets; signed licence files are out of scope here (LIC-03) | LIC-01, LIC-02 | L (Pro features only, no data risk) |
| T11 | Data exfiltration through a dependency, SDK or new network call | I | H | No analytics/ads/crash SDKs; egress guard fails the build on network APIs outside `lib/core/network/`; package audit; OSV scan (this task) | SEC-02, FND-03, SEC-08 | L |
| T12 | Sensitive content in logs, crash reports or the diagnostics zip | I | M | Content-free logging, `LogId` hashing, local-only crash capture, diagnostics zip contains metrics and logs only | FND-07, REL-02, REL-04 | L |
| T13 | Another app abuses exported components or URL/intent handlers | S, E | M | Only `MainActivity` is exported; services are `exported=false`; handlers accept only audio and `.vvprofile` files; no custom URL scheme or deep link starts recording or changes settings | SEC-09 | L (F-03) |
| T14 | Vault write abuse: path traversal, overwriting user files | T | M | Relative path validation, no `..`, overwrite refused unless the user allows it (`VaultFileExistsFailure`), outbox retry never duplicates | EXP-02, EXP-05, EXP-06 | L |
| T15 | Native memory-safety bug in the bridge on valid-looking input | T, D, E | H | C ABI with opaque handles and error codes, bounds-checked reads, sanitizer builds, fuzz targets, crash handler writes content-free reports | FND-06, vv-ffi-bridge rules | M (F-01) |
| T16 | Denial of service: huge recording, 50-job queue, low storage, memory pressure | D | M | Tiered memory limits, one heavy model at a time, resumable pipeline, stress tests | LLM-07, FND-05, QA-04 | L |

## SEC-09 bypass review

Question: can the recording safeguards be bypassed through settings, MDM, intents,
deep links or widgets? Method: review of the Android manifest, `Info.plist`, the
recording controller's start sources and the CI guard rules.

| Vector | Finding | Control |
|---|---|---|
| Settings | No setting enables background auto-start, scheduled recording, voice-activated start or "record calls". Silence auto-pause exists; it only pauses | `StartSource` enum has user-tap sources only |
| MDM / managed configuration | Managed configuration (LIC-04) may preset limits and model policy. It must not add a start source or relax CallGuard. Re-review when LIC-04 merges | ADR-SEC-09; CI guard runs on merged manifests |
| Android intents | `MainActivity` handles VIEW and SEND for audio and `.vvprofile` only. These open the import flow with attestation. No intent action starts capture. `RecordingService` is `exported=false` and `START_NOT_STICKY` | Manifest review; `check_recording_policy.sh` |
| Deep links / URL schemes | None registered. Any future scheme must not map to start-recording | Review checklist item in ADR-SEC-09 |
| Widgets, tiles, Siri/App Intents, shortcuts | SEC-09 allows a start only from a direct user tap on the app's UI, widget, quick tile or intent that is user-invoked and foregrounds the visible indicator. Add each new surface to the checklist before shipping it | ADR-SEC-09 section 5 |
| Background restart | The service is never restarted by the system; after a call or interruption, resume needs a new tap | AUD-04, AUD-05; QA-04 D-13 to D-17 |
| Forbidden APIs by plugin merge | Merged manifests and plists are scanned, not only sources | `check_recording_policy.sh` |

Result: no bypass found. Device confirmation is in QA-04 (calls) and the SEC-08
device rows.

## Findings

Register of issues found by this review. Severity is residual.

| ID | Sev | Finding | Status | Owner |
|---|---|---|---|---|
| F-01 | Medium | A malformed GGUF or other native parser input could still corrupt memory in-process. Signed models and the sideload warning reduce exposure; fuzzing is the detection control | Accepted for launch if the first 1 h libFuzzer run per target finds no crash; any crash is High and blocks | Quality |
| F-02 | Medium | Prompt injection can make extracted fields wrong or misleading (cannot reach tools, network or files) | Accepted. Review-before-export is the control; keep enabled by default | Product |
| F-03 | Low | `.vvprofile` intent filter accepts `file://` with any host. Input is size-limited and schema-validated, but the filter is broader than needed | Open, low. Follow-up: restrict to `content://` where the OS allows | Android |
| F-04 | Low | Platform decoders (not our code) parse imported audio before our WAV parser sees it. A decoder CVE is fixed by OS updates only | Accepted; documented in the privacy audit | Quality |
| F-05 | Info | Pre-launch pen test, MobSF and fuzz runs not yet executed | Open. Required before launch (see gate) | Human |

No high or critical finding is open.

## Dependency findings

`tools/ci/osv_scan.sh` runs OSV-Scanner over the pub lockfiles, Gradle
lockfiles and the native submodules (workflow `.github/workflows/osv.yml`, weekly and
on dependency changes). Ignores live in `osv-scanner.toml` with an expiry and a link
to an entry here. No entries yet because the first CI run is pending.

| Advisory | Package | Reachable? | Decision | Expires |
|---|---|---|---|---|
| none | | | | |

## Fuzzing

| Target | File | Entry point | How to run |
|---|---|---|---|
| WAV header parser | `native/fuzz/fuzz_wav.cpp` | `vv::detail::parse` in `native/bridge/vv_wav.h` | `bash native/fuzz/build_fuzz.sh wav` (standalone mutation, any clang) or `build_fuzz.sh libfuzzer wav 3600` |
| GGUF parser | `native/fuzz/fuzz_gguf.cpp` | `gguf_init_from_buffer` (pinned ggml) | `bash native/fuzz/build_fuzz.sh libfuzzer gguf 3600` on Linux or Homebrew LLVM after `native/build.sh host` |

Seeds are generated by `native/fuzz/gen_seeds.py` (synthetic silence and minimal GGUF
headers). A crash artifact is a launch blocker; add it to the corpus as a regression
seed after the fix. The standalone WAV run is exercised by `tools/ci/tests/test_sec08_threat_model.py`.
Apple clang lacks libFuzzer, so the GGUF target is unverified until run on a suitable host.

## Pre-launch pen test and MobSF

Internal runbook (owner: a person other than the implementer):

1. Build the release APK and IPA from the release candidate.
2. **MobSF** static scan of both. Triage every High finding. Expect noise about
   `RECORD_AUDIO` and Flutter engine internals; record the decision per finding.
3. Android: `adb shell dumpsys package` for exported components, run
   `am start` with crafted VIEW/SEND intents (bad MIME, oversized file, path-traversal
   file names), confirm nothing starts recording.
4. Try to read app data from another app and from an unrooted backup (`adb backup`,
   iTunes backup). Expect nothing readable.
5. Proxy test: run the app through a TLS-intercepting proxy with its CA installed on
   the device. The only traffic must be the catalog/CDN, and it must fail closed.
6. Tamper tests: edit the catalog, flip a byte in a model, swap the signature.
   Expect rejection and no install.
7. Record results in `docs/test-plans/device/SEC-08.md` and add findings above.

## Pre-launch gate

- [x] STRIDE threat model with mitigations mapped to tasks (this document).
- [x] Fuzz targets and a runnable WAV fuzz harness (`native/fuzz/`).
- [x] OSV-Scanner wired into CI (`osv.yml`, `tools/ci/osv_scan.sh`).
- [ ] First OSV run is clean or every finding triaged above (CI).
- [ ] 1 h libFuzzer run per target without a crash (human, host with libFuzzer).
- [ ] MobSF and pen test runbook executed on the release candidate (human).
- [ ] SEC-09 device rows (QA-04 calls) PASS.
- [ ] No open High or Critical in the register.

## TSK-01 Apple Reminders export (final, SEC-11, 2026-10-18)

New data flow: user-selected action items → `EKEventStore` (on-device Reminders) via our own
Pigeon plugin. Design: [ADR-TSK-01](adr/ADR-TSK-01-task-export.md); implemented by TSK-02.
Trust boundary added: app ↔ OS Reminders store (and the user's own iCloud/Exchange sync behind it).

| # | Threat | STRIDE | Sev | Planned mitigation | Residual |
|---|---|---|---|---|---|
| T17 | Content leaves the device through the reminder (iCloud/Exchange sync of the user's list, shared lists, Siri/Watch surfaces) | I | M | Content-minimal payload (item text, owner text, due date; no transcript/audio name); explicit per-item user selection; UI notice that sync is the OS setting; no automatic export | User's sync setting is outside our control |
| T18 | Over-broad permission: only full read/write exists for reminders | E, I | M | Request on first use only; read back only our linked ids (`calendarItem(withIdentifier:)`), never enumerate or fetch other reminders (the dedicated "Lumen" list is looked up by id/title among list metadata only); no background access | Permission grants access to all reminders (OS limit) |
| T19 | Prompt-injected / hostile item text (T5) written to Reminders (misleading task, very long text) | T | L | Title length cap, whitespace collapse, text passed as data only, user reviews the exact text before export; due date only from strictly parsed `due_iso`, never from speech | Misleading but user-approved text |
| T20 | Duplicate or silently re-created reminders after re-render/re-extraction | T, R | L | Stable export identity (ADR §6); no silent re-creation when the id is lost; create-only, never update/delete user reminders | Reworded re-extraction can be added again |
| T21 | Reminder text appears in logs/crash reports | I | M | Content-free logging (`LogId`), no item text in `Failure` messages or diagnostics | — |
| T22 | New permission/entitlement or network host sneaks in | I | M | ADR lists the only amendments; egress CI unchanged; privacy-audit row; SEC-11 re-check | — |

### Proof for T17–T22 (SEC-11)
| # | Control that proves it |
|---|---|
| T17 | `reminders_exporter_test.dart` (payload is the selected item only; per-item selection); UI notice (TSK-02); device row D6 egress capture |
| T18 | Exporter reads back only linked ids (`reminders_exporter_test.dart`); permission asked on first export; the macOS entitlement is device row D3 |
| T19 | `reminder_item_test.dart` (length cap, whitespace collapse, strict `due_iso` parse) |
| T20 | `reminders_exporter_test.dart` `[TSK-02/AC6]` (re-render creates no duplicate) |
| T21 | `[TSK-02/AC5]`, `[SEC-11/AC5]` in `phase2_privacy_test.dart` (counts only, host failure path included) |
| T22 | `check_egress.sh` unchanged hosts; `check_store_privacy.sh` manifests; SEC-11 re-check (this section) |

## Phase 2 threats (SEC-11, 2026-10-18)

New surfaces: iOS widget and Control, Android widget, Quick Settings tile and shortcut,
the iOS Share extension with its App Group, the on-device 3B model, Ask retrieval and chat
history, mind maps, the iOS Live Activity. Trust boundaries added: launcher/system surfaces ↔ app, other apps ↔ our
exported activity, the App Group inbox, model output ↔ UI and Markdown. The Live Activity
(AUD-13) is modelled as T33; see device row SEC-11-D8.

| # | Threat | STRIDE | Sev | Mitigation | Proof | Residual |
|---|---|---|---|---|---|---|
| T23 | Widget, Control, App Intent or tile spoofing or replay of a start request, so a recording starts without the user's tap | S, R | M | The request only navigates to the Record screen; recording still needs a tap in the app (SEC-09 rule). One pending request, 10 s monotonic expiry, replay memory of 16, intents stripped after use, history-restored intents ignored; the control intent is not discoverable | `quick_capture_handoff_test.dart`, `quick_capture_android_test.dart`, `quick_capture_artifacts_test.dart` `[QCP-02/AC4–AC6]` | A spoofed request opens the Record screen |
| T24 | Another app invokes the quick-capture intent | S, E | L | Android widget receiver `exported=false`; tile service `exported=true` but needs `BIND_QUICK_SETTINGS_TILE` (system only); the static shortcut is ours. `MainActivity` is exported for launcher/share/VIEW, so an app can send the `QUICK_CAPTURE` action: the payload is a static enum, no data flows in or out, and it only opens the Record screen (F5). iOS: the `OpenRecordScreenIntent` is `isDiscoverable = false`; other apps cannot invoke it without the Shortcuts app and the user's consent | Android manifest scan in `quick_capture_android_test.dart`; `[SEC-11/AC5]` source scan | A foreground app can bring Lumen to the Record screen (nuisance only) |
| T25 | Content leaks onto Lock Screen / Home Screen surfaces (widget, Control, tile) | I | M | Those surfaces show static text only. The widget extension has no App Group, keychain group or database access, so it cannot read recordings, titles, counts or chats. Control and tile launch the app, which then shows the app lock if enabled | `[SEC-11/AC5]` scan (no transcript, title, summary, segment, duration and similar identifiers; no file, network or audio APIs); `quick_capture_artifacts_test.dart` | None known. Device row SEC-11-D4 confirms what a locked device shows |
| T26 | Prompt injection through a transcript into Ask answers (the recording says "ignore the above and …") | T, I | M | The model has no tools and no network; it sees only retrieved passages as data (`<passages>`); output is grammar-constrained JSON, citations are accepted only for retrieved passages and timestamps, a verifier drops unsupported claims; answers render as plain `Text` (no Markdown, HTML or links), so injected markup is inert | `ask_service_test.dart` `[ASK-03/AC2]`, `ask_verifier_test.dart`, `[SEC-11/AC5]` plain-text render check. Quality gates for ASK-03 AC1 are open (see its notes); Ask is behind `ask.enabled`, off by default | A wrong or misleading answer is possible (UI says "answers can be wrong — check the sources") |
| T27 | Prompt injection into mind-map labels and their Markdown export | T | M | Output is schema-validated (`validateMindMap`: depth, count, length); labels must be grounded in the transcript; `mindMapLabel` neutralises links, images, `<`, `{{`, `[[` and bare URLs before the text reaches a note or `.mindmap.md`; the standalone file has no front-matter | `mind_map_test.dart`, `mind_map_markdown_test.dart` (MAP-02), `[SEC-11/AC5]` hostile label case | Misleading but inert text |
| T28 | Retrieval returns another user's or profile's data on a shared device | I | M | There is **no multi-user or multi-profile concept** in Lumen: one local database per app install, encrypted, and the app lock (biometric or passcode) guards it. Ask retrieves only from that database (`search_index`), never from another app or location. Device sharing therefore relies on the OS user and the app lock. | `ask_db_test.dart`; app lock tests (SEC-03) | A person who can unlock the device and the app can read everything. Not mitigated by Ask |
| T29 | Export of text the user did not select (Reminders, mind map, chat) | I | M | Reminders: only user-ticked items (TSK-02 `[AC1]`); mind map goes only where the user writes the note; chat history is never exported and has 30-day expiry, clear-all, per-chat delete, `ask.save_history` | `reminders_exporter_test.dart`, `ask_db_test.dart`, `ask_settings_test.dart` | iCloud sync of the user's Reminders list (T17) |
| T30 | Hostile file shared into the iOS Share extension, or tampering with the App Group inbox | T, D | L | The extension only copies a file; no decode there. The app validates and decodes it only after the user's attestation, through the existing import path (AUD-06) which is fuzzed (SEC-08) and size-bounded. The App Group is private to our team's signed targets | `check_ios_share_extension.sh`, AUD-06 import tests | A large file fills storage until imported or cancelled |
| T31 | A new model host or the 3B download is swapped for a malicious file | T | H | No new host; Ed25519 signed catalog, SHA-256 per file, https only, redirect hops re-checked, weights are data not code (see the model-integrity rows above) | `catalog_verifier_test.dart`, `ask01_catalog_test.dart`, `network_gateway_stream_test.dart` | As before |
| T32 | A new privacy-relevant API or permission lands without disclosure (the F1 class) | I | M | `check_store_privacy.sh` now scans the app, the shared quick-capture code, the widget and the Share extension against the matching manifests; `check_egress.sh` rejects integration hosts and credential code; the privacy doc has a checklist row per flow | `test_store_privacy.py` `[SEC-11/AC4]`, `test_egress_guard.py` `[SEC-11/AC3]` | Required-reason APIs only reached through Swift packages we do not scan |
| T33 | Live Activity shows recording state, or content, on the Lock Screen; or a push token / remote update lets a third party drive it | I, S | L | The activity carries only recording-or-paused and a timer start; static text, no recording-derived data; `pushType: nil`, no push entitlement or token, no network; no buttons or intents; a tap opens the Record screen only; ended on stop, interruption or call; `LiveActivityShared` is scanned by the egress, recording-policy and store-privacy checks | `[AUD-13/AC2–AC4]`, `check_egress.sh`, `check_store_privacy.py` | An observer of a locked phone sees that Lumen is recording and for how long (OS recording indicator). Device row SEC-11-D8 |

### Phase 2 findings
The register above has no new High or Critical. F1 (undeclared System boot time) and the
other findings are listed in [privacy-audit.md](privacy-audit.md#findings) and are fixed.
Phase 2 pre-launch items that need a human or a device are in
[device/SEC-11.md](test-plans/device/SEC-11.md).
