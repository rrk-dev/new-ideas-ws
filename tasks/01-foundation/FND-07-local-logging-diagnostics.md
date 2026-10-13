# FND-07 — Local-Only Logging & Diagnostics

**Workstream:** Foundation | **Phase:** 1 | **Size:** S | **Depends on:** FND-02 | **Source:** Gap (privacy promise rules out cloud telemetry)
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-benchmark-eval, vv-testing

## Goal
Developers and users can diagnose problems without any data leaving the device unless the user explicitly shares it.

## Scope
- [x] Structured logger with levels, rotating log files in app-private storage (size cap).
- [x] Redaction: never log transcript text, audio paths containing names, or LLM outputs at INFO+.
- [x] Performance metrics captured locally (RTF, tokens/sec, peak RAM, battery delta) per job — feeds QA-03. (Battery via injected `BatteryProbe`; platform probe → FND-09 proposed.)
- [x] "Export diagnostics" action: user-initiated zip via OS share sheet, with preview of contents.
- [x] No third-party analytics/crash SDKs (see REL-02 for crash handling).

## Acceptance Criteria
- Log files rotate at configured size; redaction unit tests pass.
- Diagnostics export contains logs + device info + metrics and no transcript content.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-07-local-logging · **Date:** 2026-10-12
- **Summary:** `app/lib/core/logging/` — `Logger` (levels, JSON-lines `LogRecord`, sinks; content
  only in DEBUG records of a debug `dev` build, compiled out of release), `Redactor`/`Sensitive`/
  `LogId` (message scrubbing + type-based field sanitizing), `RotatingFileSink`
  (`<appSupport>/vv/logs/vv.log` … `vv.4.log`, 5 × 2 MB default, `LogRotationConfig`).
  `app/lib/core/diagnostics/` — `JobMetricsRecorder`/`JobMetrics` (RTF, prefill/decode tok/s, peak
  RSS, battery delta, thermal transitions) in a bounded JSON-lines store; `DiagnosticsBundleBuilder`
  (logs re-scrubbed, DEBUG/malformed lines dropped, `device.json`, `metrics.jsonl`,
  `manifest.json`); `DiagnosticsExporter` (zip in `<tmp>/vv/diagnostics`, old exports deleted →
  `ShareService`). Riverpod providers in `diagnostics_providers.dart`; `bootstrap` wires the file
  logger, error boundary → logger, bridge versions and the `share_plus` adapter
  (`features/settings/data/`). Settings tab: "Export diagnostics" tile → preview dialog (files,
  sizes, expandable contents) → Share. CI source guard rejects interpolated log messages.
  New deps `archive`, `path_provider`, `share_plus` reviewed in ADR-FND-07.
  **Verified locally (macOS host):** format, analyze, 38 tests, coverage 92.3% (gate 80%), egress
  check. **Not verified:** real share sheet / app-private paths on iOS and Android (no Xcode/SDK);
  Android/iOS CI builds must confirm the new plugins compile.
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-07/AC1]
  - AC2: ⏳ test: [FND-07/AC2]; device: docs/test-plans/device/FND-07.md
- **Decisions:** ADR-FND-07-local-logging (Proposed)
- **Follow-ups:** FND-09 (proposed); see below

## Follow-ups
- **FND-09 (proposed) — Platform metrics probes & metrics persistence:** Pigeon battery level
  (Android `BatteryManager.BATTERY_PROPERTY_CAPACITY`, iOS `UIDevice.batteryLevel`) and thermal
  state (`PowerManager.currentThermalStatus` / `ProcessInfo.thermalState`) probes; per-job peak
  RSS from the bridge (`vv_proc_memory`) instead of the process-lifetime `ProcessInfo.maxRss`;
  move `JsonlMetricsStore` to a drift table after FND-04.
- FND-05: call `jobMetricsRecorderProvider` around each pipeline step; STT/LLM tasks pass audio
  duration and token counts/timings.
- SEC-01: exclude `<appSupport>/vv` (incl. `logs/`, `metrics/`) from backups / set file protection.
- SEC-02: copy the ADR-FND-07 dependency table into `docs/privacy-audit.md`.
- l10n: Settings/diagnostics strings are literals like the other FND-02 screens; move to ARB when
  l10n lands.

