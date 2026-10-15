# Privacy audit

Living record of every network use and every dependency review (`vv-privacy-security`).
SEC-02 owns the full egress audit (proxy capture of an e2e run); sections below are added by
the task that introduces the network use or dependency.

## Network uses
| # | What | Who calls it | Hosts | Task |
|---|---|---|---|---|
| 1 | Model catalog `catalog.json` + `catalog.json.sig` | `CatalogRepository.refresh` via `NetworkGateway` | `kModelCdnHost` (placeholder `models.vaultvoice.example`, PRODUCT-DECISION) | MDL-01 |
| 2 | Model files (`urls` in the signed catalog) | `ModelDownloader` via `NetworkGateway.getStream` (Android/host) or gateway-resolved URL → iOS background download session (MDL-02) | `kModelHosts` = our CDN + `huggingface.co` mirror; redirect-only `kModelRedirectHosts` = `us.aws.cdn.hf.co` | MDL-01 / MDL-02 |
| — | Store billing | StoreKit / Play Billing inside the OS, not our HTTP client | Apple / Google | LIC-02 |
| — | Transcript playback (not a network use) | `just_audio` `StreamAudioSource` (STT-06) serves the recording's chunks through the plugin's in-process HTTP proxy bound to **127.0.0.1** (random port); the platform player reads from it. Nothing leaves the device; Android allows cleartext only for `127.0.0.1` (`res/xml/network_security_config.xml`), iOS only `NSAllowsLocalNetworking` (no arbitrary loads) | loopback only | STT-06 |
| — | Crash reports (not a network use) | written locally; leave the device only via the OS share sheet after the user previews them — no upload endpoint (`docs/crash-triage.md`) | none | REL-02 |

Nothing else may open a connection (`tools/ci/check_egress.sh`, allowlist in
`app/lib/core/network/model_hosts.dart`). With `network_disabled` (settings key, user offline
mode or MDM managed config) the gateway refuses every request before it is sent and models are
provisioned by offline import only (MDL-04, ADR-MDL-04).

## What the model CDN / mirror can see (MDL-01)
Requests are only made when the app refreshes the catalog or the user starts a model download.
They never contain user content.

| Item | Sent? | Value / note |
|---|---|---|
| Client IP address | yes (unavoidable) | the device's public IP (or the carrier/VPN NAT) |
| TLS SNI + `Host` | yes | the catalog/model host name |
| Request line | yes | `GET /catalog/v1/catalog.json`, `GET /catalog/v1/catalog.json.sig`, `GET /<type>/<model file>` — public file names only |
| `User-Agent` | yes | `VaultVoice/1` (major version only; no OS, device model, build number) |
| `Accept` | yes | `*/*` |
| `Accept-Encoding`, `Content-Length: 0` | yes | added by `dart:io` |
| `Range` | model downloads only | byte offset for resume (MDL-02) |
| Cookies | **no** | the gateway client has no cookie jar; `Set-Cookie` is ignored |
| `Authorization` / tokens | **no** | public files only |
| Query parameters / fragments | **no** | rejected by catalog validation (`urls` must have none) |
| Device, install, advertising or user IDs | **no** | none exist in the app |
| Locale, timezone, app build, OS version | **no** | not in any header |
| Referer / Origin | **no** | not a browser |
| Request timing | yes (unavoidable) | when the app fetched which public file |

From this the operator can infer: "this IP downloaded the catalog / model X at time T with
VaultVoice". Mitigations: CDN access logs **disabled or ≤ 7 days retention** (configured when
the CDN is provisioned — PRODUCT-DECISION, ADR-MDL-01); no analytics, cookies or JS challenges
on file paths; the Hugging Face mirror is a third party whose logging we do not control (its
privacy policy applies) — it is only used when our CDN fails, and HF redirects to its own CDN
host (`*.cdn.hf.co`).

Automated evidence: `app/test/unit/models/catalog_repository_test.dart`
`[MDL-01/AC2]` asserts every catalog request is an https `GET` to an allowlisted host, only the
two manifest paths, no query/userinfo, no redirects followed, and exactly the headers
`User-Agent: VaultVoice/1` + `Accept: */*`. The on-device proxy capture is in
`docs/test-plans/device/MDL-01.md` (pending).

### Integrity (why a hostile CDN/mirror cannot hurt users)
The catalog is Ed25519-signed (pinned keys in the app, 2-key rotation), rollback-protected
(`issued_at` never older than the bundled / last accepted catalog), size-capped (1 MiB) and
schema-checked; model files are checked for exact size + SHA-256 from the signed catalog before
use. A bundled signed catalog keeps first launch and offline mode working.

## Model downloads (MDL-02)
Same request shape as the catalog (table above) plus `Range: bytes=<offset>-` on a resume and
`If-Range: <strong ETag>` when one was seen. Nothing else is added. The iOS background session
additionally sends `Accept-Language: *` (set explicitly so CFNetwork does not send the device
locale) and has cookies, cache and credential storage disabled. The download is started only
by a user action (tap "Download" or resume-on-launch of a download the user started).

### Redirect targets
`NetworkGateway.getStream` follows at most 5 redirects and checks **every hop before
requesting it**: https only, no userinfo, host in `kModelHosts` or — for redirect targets only —
`kModelRedirectHosts`. Any other target fails closed with `EgressDeniedFailure`; it is never
contacted and the downloader moves on to the next catalog URL (tests:
`app/test/unit/network/network_gateway_stream_test.dart`,
`app/test/unit/models/model_downloader_test.dart` → "redirects").

| Host | Role | Evidence (2026-10-13) | Added |
|---|---|---|---|
| `us.aws.cdn.hf.co` | Hugging Face Xet bridge CDN behind `huggingface.co/<repo>/resolve/<rev>/<file>` | `curl -I` of both pinned seed-model URLs (repeated 3×) → `302 Location: https://us.aws.cdn.hf.co/xet-bridge-us/<repo-id>/<sha>?…&Expires=…&Signature=…`; the target answers the file (`Content-Length` = catalog size, `ETag` = catalog sha256) | yes |
| `cas-bridge.xethub.hf.co`, `cdn-lfs.hf.co`, `cdn-lfs-us-1.hf.co`, `cdn-lfs-eu-1.hf.co` | other HF CDN names (resolve in DNS) | not observed as a redirect target from our network | **no** — add only after observing |
| regional `eu.aws.cdn.hf.co` / `ap.aws.cdn.hf.co` | possible regional variants | do not resolve (DNS) as of 2026-10-13 | no |

What the HF CDN sees: the device IP, `User-Agent: VaultVoice/1`, the public file path and the
signed query string Hugging Face generated (it contains `user_id=public`, an expiry, a signature
and an opaque `xip` value chosen by HF — we add no parameters). Same-host redirects on
`huggingface.co` (e.g. a moved repo, `307`) are allowed.

**iOS residual:** background `URLSession`s follow redirects without asking the app. The Dart
gateway therefore resolves and validates the chain first and hands the session the final URL;
the native delegate re-checks the current host on every progress callback and on completion
and discards the bytes (and cancels) if it is not allowlisted. A further redirect issued by an
allowlisted CDN to an unlisted host would still cause one request (public file path only, no
user content) before cancellation. To be confirmed by the device proxy capture
(`docs/test-plans/device/MDL-02.md`).

**Rejected:** `background_downloader` 9.6.4 (BSD-3-Clause, maintained) — follows up to 10
redirects natively without a hook and brings its own HTTP client outside the gateway
(ADR-MDL-02).

## Dependency review
| Name | Version | Purpose | Network? | Telemetry? | License | Last release | Decision |
|---|---|---|---|---|---|---|---|
| `cryptography` (Dart) | 2.9.0 (exact) | Ed25519 verify of the model catalog (`DartEd25519`, pure Dart) | no (grep: no `http`/`HttpClient`/`Socket` in `lib/`) | no | Apache-2.0 | 2025-11-21 | Accepted — ADR-MDL-01 |
| `crypto` (Dart, dart-lang) | 3.0.7 (exact) | streaming SHA-256 of model files; key ids | no | no | BSD-3-Clause | already a transitive dependency | Accepted — ADR-MDL-01 |
| `yaml` (Dart, dart-lang) | 3.1.4 (exact) | parse built-in / imported extraction profiles (PRF-01) | no (grep: no `http`/`HttpClient`/`Socket` in `lib/`) | no | MIT | already a transitive dependency (same version) | Accepted — PRF-01 |
| `mustache_template` (flutter/core-packages) | 2.0.5 (exact) | Markdown templates (EXP-01), strict mode | no (only `src/` imports; no `dart:io`/`http`) | no | BSD-2-Clause | 2026-06-09 (2.0.6 on 2026-09-15 is docs-only) | Accepted — ADR-EXP-01 |
| `characters` (Dart, dart-lang) | ^1.4.1 (Flutter SDK pin) | grapheme-safe slug/filename truncation (EXP-01/02) | no | no | BSD-3-Clause | already a transitive Flutter dependency | Accepted — ADR-EXP-01 |
| `unorm_dart` | 0.3.2 (exact) | NFC normalization of vault file names (EXP-02) | no (only its own `src/` imports; pure Dart tables) | no | MIT | 2025-10-01 (0.3.3 of 2026-10-04 is < 2 weeks old) | Accepted — EXP-02 (no Dart SDK API for Unicode normalization) |
| `file_selector` (+ `file_selector_android` 0.5.2+11, `file_selector_ios` 0.5.3+6) | 1.1.0 (exact) | system file picker for offline model import (MDL-04) | no (source grep: no `HttpURLConnection`/`OkHttp`/`URLSession`/`http`; Android copies the picked document into `cacheDir`, iOS document picker in import mode) | no | BSD-3-Clause (flutter.dev) | 2025-11-21 (platform pkgs 2026-08/09) | Accepted — ADR-MDL-04 |
| `record` (+ `record_android` 2.2.0, `record_ios` 2.1.1, `record_platform_interface` 2.1.0) | 7.1.2 (exact) | microphone PCM stream via the standard OS APIs (AVAudioEngine / `AudioRecord`) — AUD-01 | no (grep: no `http`/`HttpClient`/`Socket`/`URLSession`/`HttpURLConnection` in Dart, Kotlin or Swift sources) | no | BSD-3-Clause | 2026 (7.1.2) | Accepted — ADR-AUD-01; adds only `RECORD_AUDIO` to the merged manifest; its native code maps every Android audio source, our Dart call site is restricted to `mic`/`voiceRecognition` (SEC-09 CI guard) |
| `just_audio` (+ `just_audio_platform_interface` 4.6.0, `just_audio_web` 0.4.16) | 0.10.6 (exact) | transcript playback with seek (STT-06); `StreamAudioSource` over the chunk reader so encrypted chunks can decrypt on the fly (vv-whisper-stt) | only loopback: Dart `HttpServer.bind(127.0.0.1)` proxy for stream sources; Android ExoPlayer `DefaultHttpDataSource` is used only for that loopback URL (our sources are never remote) | no | MIT | 2026 | Accepted — STT-06. Playback only (never records, SEC-09); no permissions added to the merged manifest |
| `audio_session` (transitive) | 0.2.4 | audio-session plumbing used by just_audio; we never configure a session with it (recording owns the session, AUD-04) | no (grep of android/ios sources: no `URLSession`/`HttpURLConnection`/`OkHttp`) | no | MIT | 2025 | Accepted — STT-06 |
| `rxdart` / `synchronized` (transitive) | 0.28.0 / 3.5.0 | stream helpers / locks used by just_audio | no | no | Apache-2.0 / MIT | 2024–2025 | Accepted — STT-06 |
| `cryptography` (Python, pyca) | 46.0.3 | `tools/model-catalog` signing CLI only (not shipped in the app) | no | no | Apache-2.0 OR BSD-3-Clause | 2025 | Accepted — ADR-MDL-01 |
| `flutter_local_notifications` | 22.3.1 (exact) | Local "note ready" / "processing failed" notifications (APP-04) | no (grep of `lib/`, `android/src`, `ios/`: no `HttpClient`/`URLSession`/`OkHttp`/`HttpURLConnection`/socket; only local asset/file `InputStream`s for icons) | no (no analytics/Firebase/Sentry) | BSD-3-Clause | 2026-09-13 (22.3.2 on 2026-10-12; active) | Accepted — APP-04. Purely local OS notifications, no push service. Adds `POST_NOTIFICATIONS` + `VIBRATE` to the merged Android manifest (no call/microphone permissions) |
| `flutter_local_notifications_platform_interface` / `_linux` / `_windows` / `_web` | 12.2.0 / 8.0.2 / 3.1.1 / 1.0.0 | Federated parts of the above; only the iOS/Android implementations are registered in our app | no | no | BSD-3-Clause | 2026 | Accepted — APP-04 |
| `timezone` (transitive) | 0.11.2 | Time-zone database for scheduled notifications (unused by us) | `lib/standalone.dart` can fetch tz data over HTTP when given an `http` URI — never imported by the plugin or by us (they import `timezone.dart` only), tree-shaken | no | BSD-2-Clause | 2025 | Accepted — APP-04 |
| `dbus` (transitive, Linux implementation only) | 0.8.0 | D-Bus client used by `flutter_local_notifications_linux`; not reachable on iOS/Android (Linux plugin not registered; tree-shaken) | local Unix socket to the D-Bus daemon on Linux desktops only | no | MPL-2.0 (file-level copyleft; unmodified, not shipped in mobile binaries) | 2025 | Accepted — APP-04; SEC-05 to list in `docs/licenses.md` |
| `com.android.tools:desugar_jdk_libs` (Gradle) | 2.1.4 | Core library desugaring required by `flutter_local_notifications` on Android | no | no | GPL-2.0 with Classpath Exception (OpenJDK, Google-distributed; the exception permits linking into proprietary apps) | 2024 | Accepted — APP-04; SEC-05 to confirm in `docs/licenses.md` |
| `re_editor` | 0.10.0 (exact) | Template code editor with syntax highlighting + autocomplete (EXP-07) | no (grep of `lib/`: no `dart:io`/`HttpClient`/`Socket`/`package:http`) | no | MIT | 2026-07-01 | Accepted — EXP-07 (skill: preferred over `flutter_code_editor`) |
| `re_highlight` | 0.0.3 (exact) | Highlighting rules (`langHandlebars`) + themes for `re_editor` | no (grep hits are only keyword lists of other languages, e.g. `"HttpClient"` in `arduino.dart`) | no | MIT | 2024-02-05 (stable; rule tables only) | Accepted — EXP-07 |
| `isolate_manager` / `isolate_contactor` (transitive) | 4.1.5+1 / 4.1.0 | `re_editor` runs highlighting off the UI isolate | no | no | MIT | 2024–2025 | Accepted — EXP-07 |
| `flutter_markdown_plus` (+ `markdown` 7.3.1 transitive) | 1.0.12 (exact) | Rendered Markdown preview in the template editor (EXP-07) | **default image builder fetches `http(s)` images** (`Image.network` in `_functions_io.dart`) — we always pass `imageBuilder` that renders only the alt text, and no `onTapLink`, so the preview never touches the network | no | BSD-3-Clause (flutter.dev / Foresight) | 2026-07-10 | Accepted — EXP-07 with the no-network `imageBuilder` (template_editor_screen.dart) |

## Models (license must allow our use and, for our CDN, redistribution — SEC-05)
| Model | Source (pinned revision) | License | Redistribution on our CDN |
|---|---|---|---|
| `ggml-tiny.en.bin` (Whisper tiny.en) | `huggingface.co/ggerganov/whisper.cpp` @ `5359861c739e955e79d9a303bcbc70fb988958b1` | MIT (OpenAI Whisper weights; whisper.cpp MIT) | allowed (keep license notice) |
| `qwen2.5-0.5b-instruct-q4_k_m.gguf` | `huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF` @ `9217f5db79a29953eb74d5343926648285ec7e67` | Apache-2.0 | allowed (keep LICENSE + NOTICE) — SEC-05 to confirm |
