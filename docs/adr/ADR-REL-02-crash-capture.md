# ADR-REL-02 — Local crash capture: own async-signal-safe handler vs a vetted crash library

- **Status:** Proposed (host-measured only; device runs pending, see `docs/test-plans/device/REL-02.md`)
- **Date:** 2026-10-13
- **Task:** REL-02
- **Deciders:** Claude Code (implementer); human reviewer + independent verifier pending
- **Supersedes:** —

## Context
We want crash data we can act on without breaking "no data leaves the device" (`AGENTS.md`,
`vv-privacy-security`). Constraints:
- No crash/analytics SDKs, no upload endpoint (egress policy). A report leaves the device only
  when the user shares it (preview → OS share sheet), like the FND-07 diagnostics export.
- Reports must be content-free: no transcript text, prompts, file names. A minidump-style
  capture of stack/heap memory is a content leak (transcripts and LLM output live in native
  memory during STT/LLM jobs).
- Both platforms (iOS 16+, Android 26+ arm64) with one code path in `native/bridge` (the only
  native code Dart talks to); the bridge is plain C (`vv-ffi-bridge`).
- The handler runs in signal context: only async-signal-safe calls, write to a descriptor opened
  before the crash.
- The OS/store crash reporters (App Store Connect, Play Console vitals) must keep working: we
  must chain, not swallow, signals.
- Symbolication with standard tools (`ndk-stack`, `llvm-symbolizer`, `atos`, `flutter
  symbolize`) against symbols kept privately by REL-01.
- Dart errors are handled separately in Dart (`FlutterError.onError`,
  `PlatformDispatcher.onError`), building on FND-07's error boundary.

## Options
1. **Own minimal handler in the bridge** (`native/bridge/vv_crash.{h,c}`, ~550 lines of C):
   sigaction for SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGABRT/SIGTRAP, frame-pointer unwind from the
   signal `ucontext`, module table (name, build id, load address) snapshotted at install,
   text report in tombstone format, chain to the previous handler.
2. **Crashpad** (BSD-3, Chromium): out-of-process handler, minidumps. Needs a separate handler
   process/executable on Android, GN build, strip its upload/HTTP code; minidumps include stack
   memory.
3. **Breakpad** (BSD-3): in-process minidump writer (Android/Linux; iOS client is legacy).
   Minidumps include stack memory; symbolication needs `dump_syms` + `minidump_stackwalk`.
4. **KSCrash / PLCrashReporter** (MIT, iOS only) + something else for Android: two
   implementations, Objective-C dependencies, reporting/upload features to disable.
5. **sentry-native** (MIT): wraps Crashpad/Breakpad; a telemetry SDK — forbidden by policy.
6. **Do nothing**: rely on App Store Connect / Play Console OS reports only (users' OS-level
   opt-in, store builds only, no beta/dev builds, no Dart context).

## Criteria (weights fixed before deciding)
| Criterion | Weight |
|---|---|
| Privacy: report content minimal by construction, no network code | 30% |
| One implementation for Android + iOS inside the bridge | 20% |
| Integration effort / build complexity / binary size | 20% |
| Symbolication with standard, offline tools | 15% |
| License & maintenance | 10% |
| Host testability (forced crash in CI) | 5% |

## Evidence
Environment: macOS 27.0.1 arm64 (Apple clang 21), Linux arm64 and Linux x86_64 (Debian
bookworm, gcc 12, under podman) — host only; no device available.

| Measure | Result |
|---|---|
| Forced SIGSEGV / SIGABRT / SIGTRAP in a forked child (`native/tests/crash_test.c`, ctest `vv_crash`) | child dies of the original signal (chaining to the default action works); report complete |
| Forced SEGV → shared file → `tools/crash/symbolize.py` (`[REL-02/AC1]` pytest + Dart e2e) | frame #00 resolves to `vv_crash_force_segv (vv_crash.c:<line of the faulting store>)`, callers `crash_test_level2/1` resolved — macOS (atos + dSYM), Linux arm64 + x86_64 (addr2line) |
| `abort()` trace | symbolized through libc on macOS and Linux arm64; on Linux x86_64 the walk stops inside glibc `raise()` (glibc there is built without frame pointers) |
| `libvv_native` size (host, Release) | 6 507 968 → 6 525 856 bytes (+17.9 KB); ~200 KB static BSS (module table + 64 KB alt stack) |
| Exports | only `vv_*` (ctest `vv_exports` still passes) |
| Report content | signal, si_code, fault address, frames (module-relative pc + module basename + build id), load addresses, app build string, `uname` OS release, ABI, time. No registers besides pc/lr/fp/sp (used, not written), no memory, no paths. Test asserts no `/` in the report. |

Options 2–5 were not prototyped: each fails a hard constraint on paper (memory capture
contradicts the privacy criterion; two code bases or a separate handler process contradict
the single-bridge criterion; Sentry is forbidden). Option 6 remains the baseline next to
option 1.

## Decision
We choose **Option 1 (own minimal handler) plus Option 6 as the baseline**:
- `vv_crash_install(path, app_build)` opens/truncates `<appSupport>/vv/crash/native-current.vvcrash`
  (0600) and installs handlers with `SA_SIGINFO | SA_ONSTACK` (64 KB alternate stack for the
  installing thread; bionic gives every thread one).
- Handler: one writer at a time (second crashing thread waits ≤ 1 s), writes the report line
  by line (`write`), `fsync`, restores the previous handlers, re-raises user-sent signals and
  `SIGABRT`, returns for hardware faults so the instruction faults again into the previous
  handler (debuggerd tombstone / Play vitals, iOS ReportCrash).
- PAC/TBI bits are stripped with `xpaclri` (HINT #7, a no-op on CPUs without PAC).
- Dart side: `bootstrap` harvests a non-empty live file (→ `native-<UTC>.vvcrash`) **before**
  re-installing; Dart errors go to `dart-<UTC>.vvdart` (type + stack, never the message).
  Next launch shows "share crash report?" → full preview → share sheet. No upload endpoint.
- `tools/crash/symbolize.py` + `docs/crash-triage.md` document symbolication.

## Consequences
- Positive: content-free reports by construction; one C file, no new dependency, no network
  code; tombstone-format backtrace lines meant for `ndk-stack` (not run here: no NDK — device row); host-testable end to end.
- Negative / risks (with mitigation):
  - Frame-pointer unwinding only (CFI unwinding is not async-signal-safe): frames through code
    built without frame pointers truncate the trace. Our C is built with
    `-fno-omit-frame-pointer`; Apple arm64 ABI and Android arm64 keep frame pointers by
    default (verify on device; follow-up to build ggml/whisper/llama with frame pointers if
    traces stop inside them). Frame 0 + `lr` are always present.
  - Modules loaded after install (late `dlopen`) appear as `<unknown>` with an absolute pc.
  - Android ART uses SIGSEGV internally (implicit null checks); `libsigchain` gives ART the
    first claim, so our handler only sees real crashes — **must be verified on a device**
    (row in the device checklist).
  - iOS: a debugger's Mach exception handler sees faults first (expected under Xcode); stack
    overflow on threads other than the installing one may not be reported.
  - The live file is truncated at each launch: a crash during the harvest window is lost; the
    OS reports remain.
- Follow-up tasks: see REL-02 `## Follow-ups` (dSYM for `vv_native.framework`, pass
  `VV_BUILD_NAME/NUMBER` as dart-defines in the release build, frame pointers for ggml).
