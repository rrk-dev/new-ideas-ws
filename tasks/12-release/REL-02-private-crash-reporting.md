# REL-02 — Privacy-Preserving Crash Reporting

**Workstream:** Release | **Phase:** 4 | **Size:** S | **Depends on:** FND-07 | **Source:** Gap (no Crashlytics/Sentry cloud by default given privacy promise)
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release, vv-privacy-security, vv-ffi-bridge, vv-decision-records, vv-testing

## Goal
Get actionable crash data without violating "no data leaves the device".

## Scope
- [x] Capture Dart + native (signal handler) crashes to local files.
- [x] On next launch, offer "Send crash report" — user reviews content, sends via email/share sheet. No upload endpoint (egress policy) unless a future ADR adds one to the allowlist.
- [x] Rely on App Store Connect / Play Console OS-level crash reports (users' OS-level opt-in) as baseline.
- [x] Symbolication tooling using privately stored symbols (REL-01).

## Acceptance Criteria
- A forced native crash produces a symbolicated report from a user-shared file.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/REL-02-private-crash-reporting · **Date:** 2026-10-13
- **Summary:** Native: `native/bridge/vv_crash.{h,c}` — async-signal-safe SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGABRT/SIGTRAP handler writing a tombstone-style, content-free report (signal, fault addr, frame-pointer backtrace as module-relative pcs + module basename + build id, load addresses, app build, OS) to a descriptor pre-opened by `vv_crash_install`; chains to the previous handler (OS reporter keeps working); exported as `vv_crash_*` (additive CMake/exports lines), ctest `vv_crash` (forced crashes in forked children). Dart FFI: `packages/vv_native/lib/vv_crash.dart` + `ffigen_crash.yaml` → `vv_crash_bindings.g.dart` (separate from `vv_bridge.h` bindings). App: `app/lib/core/crash/` (`CrashReportStore`, `DartCrashRecorder` — type + stack, never the message, `CrashReporting.start` harvests the previous native report before re-arming, `crashReportsProvider`), `installErrorBoundary(onCrash:)`, `bootstrap` wiring, `CrashReportGate` (next-launch prompt → full preview → share sheet; `MaterialApp.builder` in `app.dart`) and Settings hook `CrashReportSettingsSection` (+ dev-only forced-crash tiles) in `features/settings/presentation/crash_reports.dart`. Tooling/docs: `tools/crash/symbolize.py` (atos / llvm-symbolizer / addr2line / `flutter symbolize`), `docs/crash-triage.md` (OS/store baseline, private symbols from REL-01, `flutter symbolize` / `ndk-stack` / `atos`), `docs/privacy-audit.md` row. No new dependencies, no network code.
- **Acceptance evidence:**
  - AC1: ⏳ test: [REL-02/AC1]; device: docs/test-plans/device/REL-02.md; artifact: docs/crash-triage.md
- **Host evidence for AC1:** `app/test/unit/crash/native_crash_e2e_test.dart` (real handler crashes a process into the app crash dir → `CrashReporting.start` harvests → `crashReportsProvider.share` → shared `.txt` → `symbolize.py` resolves frame #00 to `vv_crash_force_segv (vv_crash.c:<line>)`); `tools/crash/tests/test_crash_symbolize.py` (`REL_02_AC1`, passes on macOS arm64 + Linux arm64/x86_64 via podman; the abort-trace sub-test skips on x86_64 glibc, no frame pointers); ctest `vv_crash` (3/3 ctest pass).
- **Decisions:** ADR-REL-02-crash-capture (Proposed: own handler vs Crashpad/Breakpad/KSCrash/PLCrashReporter/sentry-native).
- **Privacy checklist:** no network code (egress check passes); reports content-free by construction (no messages, memory or paths — tests assert); no new dependency; files under `<appSupport>/vv/crash` (0600 native file), shared copies in app temp; recording policy check passes, nothing can start recording.
- **Follow-ups:** see below.

## Follow-ups
- REL-01: pass `--dart-define=VV_BUILD_NAME=$VV_BUILD_NAME --dart-define=VV_BUILD_NUMBER=$VV_BUILD_NUMBER` in `tools/release/build_release.sh` so crash reports carry the version (today they show `0.0.0+0 <flavor>`; module build ids still identify the build).
- FND-06 / REL-03: emit `vv_native.framework.dSYM` from `native/build.sh ios` (dsymutil) and keep it with the release symbols; consider `-fno-omit-frame-pointer` for ggml/whisper/llama if device traces stop inside them (ADR-REL-02 risks).
- APP-xx (Settings owner): place `CrashReportSettingsSection` where it fits (currently appended after Export diagnostics in `settings_screen.dart`).


## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[REL-02/AC1]` (`native_crash_e2e_test.dart` in the 785, `tools/crash/tests/test_crash_symbolize.py` in the pytest 35, and ctest `vv_crash` passed). The e2e compiles `vv_crash.c`, force-crashes a child, harvests the tombstone on the next `CrashReporting.start`, shares a `.vvcrash.txt` via the share sheet, and `symbolize.py` resolves frame `#00` to `vv_crash_force_segv (vv_crash.c:<line>)`. Artifact `docs/crash-triage.md` exists. Checked the e2e fails when the function is renamed to `forced_fault` (frame text no longer contains `vv_crash_force_segv`). Device rows (iPhone, Android, ART coexistence, Dart error) are blank.
- **Adversarial checks:** Reports are content-free in the test (no message text). Share does not upload; egress check OK. Handler chains to the previous action so the OS reporter still runs (documented and covered by the device logcat/Organizer rows). No new dependency. `tasks.py verify REL-02 --run` short-circuits on the pending device rows; the host tagged tests passed before the mutation.
- **Skill/rule compliance:** Capture is local files plus a user-reviewed share sheet. No Crashlytics/Sentry. Symbolication uses private symbols (REL-01). ADR-REL-02 Proposed (own handler vs Crashpad/Breakpad). Signal handler is async-signal-safe C, not a third-party native crash SDK.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/REL-02.md has no PASS result with a date; dependency FND-07 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
- Codex review 2026-10-15 (open): dSYM packaging (`-debug-symbols`) and collection are written but unrun (needs macOS/Xcode); verify on first release build that `symbols-ios` contains `native/dSYMs/<slice>/vv_native.framework.dSYM`.
