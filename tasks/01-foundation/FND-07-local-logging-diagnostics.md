# FND-07 — Local-Only Logging & Diagnostics

**Workstream:** Foundation | **Phase:** 1 | **Size:** S | **Depends on:** FND-02 | **Source:** Gap (privacy promise rules out cloud telemetry)
**Status:** in-progress
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



## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ❌ Tagged tests pass for ordinary rotation/restart and INFO+ redaction (paths, quotes/JSON, filenames, sensitive fields), but oversized-record adversarial test exceeds the configured per-file cap.
  - AC2: ✅ Host tests check zip entries, INFO+ filtering, malformed/DEBUG-line dropping, redaction sentinels, device info/metrics, preview-before-share and cancellation. Real iOS/iPad/Android share-sheet/private-path rows remain blank and require device runs.
- **Adversarial checks:** Changed plain-string field redaction to return the original string; [FND-07/AC1] redaction tests failed and passed after git checkout restored redaction.dart. Unchanged-source probe wrote 100 numeric INFO fields through Logger into RotatingFileSink(maxFileBytes: 256, maxFiles: 2): vv.log was 1,363 bytes, violating the cap. Probe: /tmp/vv-verify-a/adversarial_logging_test.dart; output: logging-adversarial.log. Reviewed zip filtering, no pre-confirm share and filesystem-error swallowing.
- **Skill/rule compliance:** Local-only sinks, private paths and share-preview flow inspected against privacy/architecture/testing/benchmark and software-security guidance. No runtime network/SDK was added. Export metrics still use documented injectable probes; actual platform battery probe is a follow-up. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** 
  1. RotatingFileSink.write only rotates when _size > 0 and does not reject/truncate/split a record larger than maxFileBytes. A large record is written whole into an empty file (also immediately after rotation), exceeding the configured per-file and total storage caps. Add oversized-record handling and a regression asserting the cap for large records.
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-07 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/FND-07-verify.log`.

## Rework
- **Agent:** Claude Code · **Branch:** task/FND-07-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged).
- **Issue 1 (a single oversized record overflows the per-file/total cap):** reproduced first with a failing
  regression test (commit `daf8952`): `[FND-07/AC1] an oversized record never exceeds the per-file or total cap
  (regression: Codex FAIL 2026-10-14)` in `app/test/unit/logging_test.dart` — `RotatingFileSink(maxFileBytes: 256,
  maxFiles: 2)` + `Logger.info` with 100 numeric fields, on an empty file, after a normal line and right after a
  rotation; failed with `vv.log` = 1,755 bytes (> 256). Fix in `app/lib/core/logging/rotating_file_sink.dart`
  (`_bounded`): a record whose encoded line exceeds `maxFileBytes` is **replaced, never split** (every line stays one
  parseable JSON object) by a content-free marker with the same time/level/tag and fields
  `{truncated: true, bytes: <original size>, dropped_fields: <n>}`; if the (already redacted) message is itself too
  long, the message becomes the constant `record truncated`; if even that does not fit (a cap of a few dozen bytes)
  the record is dropped. Conservative choice: fields are dropped wholesale rather than partially kept, so no
  cut-off value can be misread. The test asserts every file ≤ 256 bytes, total ≤ 2 × 256, ≤ 2 files, every line
  parses, both marker forms (event name kept + `dropped_fields: 100`; `record truncated` for a 2,000-char sink-level
  message), and that logging continues normally afterwards. Second test `[FND-07/AC1] a cap too small for even the
  marker drops the record` (16-byte cap) asserts the drop path.
  Mutation check (2026-10-14): `_bounded` changed to always return the full line → `fvm flutter test
  test/unit/logging_test.dart` → both new tests failed; restored with `git checkout` → `+10: All tests passed!`.
- **Still needed (unchanged):** AC2 device rows in `docs/test-plans/device/FND-07.md` (real share sheet /
  app-private paths on iPhone, iPad and Android).
