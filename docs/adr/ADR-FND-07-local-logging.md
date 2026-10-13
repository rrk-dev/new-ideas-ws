# ADR-FND-07 — Local-only logging, metrics and diagnostics export

- **Status:** Proposed
- **Date:** 2026-10-12
- **Task:** FND-07
- **Deciders:** Claude Code (implementer); human reviewer + independent verifier pending
- **Supersedes:** —

## Context
The privacy promise rules out cloud telemetry and crash SDKs, but developers and users still need
to diagnose problems. Constraints (`AGENTS.md`, `vv-privacy-security`): no network, no content
in logs at INFO+ (transcripts, LLM output, prompts, file/folder names, vault paths, speaker
names), logs in app-private storage with a size cap (5 × 2 MB), a user-initiated export
(zip → preview → OS share sheet), per-job performance metrics for QA-03. Dependencies must be
reviewed (network/telemetry, license, maintenance) and pinned via `pubspec.lock`.

## Options
1. **Own small logger + `archive` + `share_plus` + `path_provider`** — ~400 lines of first-party
   Dart (`lib/core/logging`, `lib/core/diagnostics`), pure-Dart zip, the de-facto Flutter share
   sheet plugin, the official app-directories plugin.
2. **`logging` / `logger` pub packages + same plugins** — generic loggers; redaction, rotation
   and the content-free field model would still be ours (rotation needs another package such as
   `logger`'s file output, which has no size cap).
3. **Native share sheet via Pigeon (no `share_plus`)** — Kotlin `ACTION_SEND` + our own
   `FileProvider` and manifest entries, Swift `UIActivityViewController`.

## Criteria (weights fixed before deciding)
| Criterion | Weight |
|---|---|
| Privacy / network behaviour | 30% |
| Content-safety enforceability (redaction by construction, testable) | 25% |
| Integration effort & merge risk with parallel tasks (manifests, AppDelegate) | 20% |
| License & maintenance health | 15% |
| Testability on host CI | 10% |

## Evidence
Dependency review (versions resolved in `app/pubspec.lock`, sources read in the pub cache on
2026-10-12):

| Package | Version | Purpose | Network? | Telemetry? | License | Maintenance | Decision |
|---|---|---|---|---|---|---|---|
| `archive` | 4.5.1 | zip the export (pure Dart) | no | no | MIT | active (already a transitive dep) | adopt |
| `path_provider` | 2.1.6 | `<appSupport>` / tmp dirs | no | no | BSD-3 (flutter.dev) | first-party Flutter | adopt |
| `share_plus` | 13.3.1 (+ `share_plus_platform_interface` 7.2.0) | OS share sheet | no — `http`/`URLSession` grep hits are doc links and the web-only mailto/download fallbacks, which we disable | no | BSD-3 (Flutter Community) | active, Plus Plugins | adopt |

`share_plus` ships its own Android `FileProvider` (`${applicationId}.flutter.share_provider`, not
exported, `grantUriPermissions`) restricted to its cache sub-folder, and an iOS
`PrivacyInfo.xcprivacy`; it adds no permissions. Transitive additions (`cross_file`, `mime`,
`url_launcher_{linux,windows,web,platform_interface}`, `win32`, `xdg_directories`) are desktop/web
implementations not compiled into the Android/iOS app (`url_launcher` mobile implementations are
not pulled in).

Option 2 adds a dependency without removing any of our code (redaction/field sanitizing and the
rotation cap are the substance). Option 3 means editing `AndroidManifest.xml`, `res/xml`,
`MainActivity`/`AppDelegate`, which SEC-09, EXP-03 and EXP-04 are changing in parallel, and it
cannot be built locally (no Xcode/NDK).

## Decision
We choose **Option 1**.
- `Logger` (`lib/core/logging/logger.dart`): levels DEBUG/INFO/WARNING/ERROR, JSON-lines records,
  message passed through `Redactor.redact` (URIs, paths, media/document file names, quoted/JSON
  text, e-mail, phone; 160-char cap); fields sanitized by type — numbers/bools/enums/durations/
  dates and `LogId` pass, plain strings and `Sensitive` become `<redacted:N>`. `Sensitive`
  content is revealed only by DEBUG records in a **debug build of the dev flavor**
  (`kDebugMode && flavor.isDev`; `kDebugMode` is const, so the branch is compiled out of
  release). `prod` logs INFO+ only.
- Messages must be constant strings: `test/unit/log_call_guard_test.dart` fails CI on an
  interpolated or non-literal message, because no runtime heuristic can detect free prose.
- `RotatingFileSink`: `<appSupport>/vv/logs/vv.log` … `vv.4.log`, rotate before a write would
  exceed 2 MB, synchronous appends (last lines before a crash survive).
- Metrics: `JobMetricsRecorder` → `JobMetrics` (RTF, prefill/decode tok/s, peak RSS via
  `ProcessInfo.maxRss`, battery delta via `BatteryProbe`, thermal transitions) stored as JSON
  lines (`<appSupport>/vv/metrics/metrics.jsonl`, newest 500).
- Export: `DiagnosticsBundleBuilder` → logs (DEBUG and malformed lines dropped, re-redacted),
  `device.json` (OS, version, locale, CPUs, Dart, flavor, bridge versions), `metrics.jsonl`,
  `manifest.json` → preview dialog → zip in `<tmp>/vv/diagnostics/` (previous exports deleted)
  → share sheet. Nothing is sent by the app.

## Consequences
- Positive: no telemetry path exists; content safety is enforced by types, a CI source guard and
  an export-time re-scrub; all of it runs in host `flutter test`.
- Negative / risks: the message redactor is heuristic (mitigated by the constant-message guard);
  `ProcessInfo.maxRss` is a process-lifetime high-water mark, not per-job (switch to
  `vv_proc_memory` from the bridge when it exists); battery has no platform probe yet; metrics
  live in a file until the drift DB lands; sync log writes run on the calling isolate (fine for
  the expected volume; background isolates need their own sink or a port).
- Follow-up tasks: FND-09 (proposed) — platform battery/thermal probes, move metrics to the DB
  (after FND-04), wire `JobMetricsRecorder` into the pipeline (FND-05), backup exclusion of `vv/`
  (SEC-01), copy the dependency table to `docs/privacy-audit.md` when SEC-02 creates it.
