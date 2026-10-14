# ADR-INT-W2 — Wave-2 integration decisions (one native backend design, one backend policy)

- **Status:** Proposed (host-verified; Android/iOS device rows of the merged tasks still pending)
- **Date:** 2026-10-14
- **Task:** none (integration branch `integration/wave-2`; merges FND-01/06 reworks, LIC-01, PRF-01,
  EXP-01/02, MDL-02/04, AUD-01/04/05/07, STT-01/02/03, LLM-01..05/07, REL-01/02, APP-03/04/06)
- **Deciders:** Claude Code (integration engineer); pending verifier and the user
- **Supersedes:** ADR-LLM-03 decision 3 (in part — see the note there); keeps ADR-STT-02

## Context
The wave-2 task branches were built in parallel. STT-02 and LLM-02/03 each added a native GPU
backend design and a Dart backend policy; REL-02 added a second ffigen config; MDL-04 and LLM-07
shipped placeholders for LIC-01; APP-06 externalised UI strings while other branches added new
ones; APP-03 replaced the Settings screen other branches mounted tiles on. Main also received
several of these branches through GitHub web-editor merges that dropped content (see
"Repairs" below). The integration must produce one consistent design without adding features.

## Decisions
1. **Native GPU backends = runtime-loaded modules only (STT-02).** `VV_GGML_BACKEND_DL` +
   `VV_GGML_VULKAN` / `VV_GGML_OPENCL`, `vv_backends_load/describe/dynamic`, `c++_shared` and
   16 KB flags stay. LLM-03's static `VV_ANDROID_VULKAN` / `VV_ANDROID_OPENCL` options are
   removed; the names remain as deprecated aliases that set the DL options (so they still need
   `VV_GGML_BACKEND_DL=ON` and can never link a GPU backend statically). Reason (ADR-STT-02): a
   static OpenCL backend makes `libvv_native.so` fail to load without `libOpenCL.so`, and static
   Vulkan enumerates devices before any allow/deny decision.
2. **One bridge ABI.** One `vv_error.h` (REL-02's `VV_CRASH_*` codes are now aliases of it);
   `vv_threads.h` (whisper, header-only, internal) and `vv_cpu.h` (LLM, internal) coexist;
   `vv_cpu_perf_cores` is exported once (`vv_llama.cpp`); `vv_jsg`, `vv_crash`, the whisper and
   llama engines are all in `vv_native`. Export lists contain only `vv_*`.
3. **One ffigen config / one bindings file.** `vv_bridge.h` includes `vv_error.h`,
   `vv_whisper.h`, `vv_llama.h` and `vv_crash.h`; `packages/vv_native/ffigen.yaml` lists all of
   them; `ffigen_crash.yaml` and `vv_crash_bindings.g.dart` are gone (`VvCrash` uses
   `VvBindings`). `tools/ci/check_bindings.py` now scans every bound header and fails on a second
   bindings file.
4. **One Dart backend policy for STT and LLM** (per the LLM agent's recommendation):
   `core/platform/backend_policy.dart` (STT-02) is the single source — `GpuBackend` mask bits,
   `GpuInfo`, `GpuRules` allow/deny (deny wins; Android shipped empty ⇒ CPU), and
   `GpuTrialStore`/`GpuTrialGuard` as the only crash sentinel (+ `failed()` for a bridge GPU→CPU
   fallback and `resetAll()`, from LLM-03; persisted durably by `core/platform/gpu_trial_file.dart`).
   One decision function `chooseBackend(BackendPolicyInput(platform, foreground, gpu, forceCpu, …))`;
   background ⇒ CPU is a hard rule on every platform (iOS forbids GPU work in the background).
   LLM keeps `DeviceCapabilities` — now built on `vv_backends_describe` (gpu/igpu entries, index =
   the LLM bridge's `gpu_device`) — and `LlmBackendChoice` as the per-context output via
   `chooseLlmBackend(caps, platform, foreground, crashedBackends, userForceCpu, rules)`; it returns
   `null` when `vv_cpu_supported()` fails (no SIGILL). Removed: `GpuBackendGuard`,
   `FileBackendHealthStore`, `MemoryBackendHealthStore`, `GpuAllowlist`/`GpuAllowRule`,
   `kAndroidGpuAllowlist`, `chooseAndroidBackend`, `LlmBackendPolicy`, `LlmPlatform`, LLM-03's
   duplicate `GpuBackend` enum. The `[LLM-03/AC2]` tests moved to
   `app/test/unit/extraction/llm_backend_choice_test.dart`.
5. **Interfaces now joined.** `NativeSchemaGrammarConverter implements SchemaGrammarConverter`
   (PRF-01). `LlmPlanGate.entitlements(EntitlementService)` and `EntitlementCustomModels`
   (default `customModelEntitlementProvider`) read LIC-01's `Feature.largeLlm` /
   `Feature.sideloadCustomModel`; APP-03's Settings License hook (`licenseSettingsPortProvider`)
   is `EntitlementLicensePort` over the same service. Under the default **personal** build these
   follow LIC-01's personal column (Free plan shown in Settings, as before; custom-model import
   still also needs the user's "advanced" setting); under a commercial Free plan they deny —
   identical to the old placeholders.
6. **UI hooks.** APP-03's Settings screen is kept; REL-02's `CrashReportSettingsSection` sits in
   the Privacy section after diagnostics export, LLM-04's dev-only `LlmDebugTile` at the end, and
   MDL-04's `ModelImportTile` on Settings → Models (the MDL-03 screen placeholder) so the Settings
   golden does not change. `MaterialApp.builder` hosts REL-02's `CrashReportGate`; `App` keeps the
   MDL-02 resume listener and APP-06 localizations.
7. **Strings (APP-06).** New user-facing strings from AUD-05/07 (battery guidance, recovered
   recording prompt), MDL-04 (import tile) and REL-02 (crash dialogs/settings, incl. its dev
   tiles) are in `app_en.arb`. Only dev-flavor-only debug *screens* are exempt, the same way as
   the CallGuard debug screen: `recording_debug_screen.dart` (AUD-01) and `llm_debug_screen.dart`
   (LLM-04, incl. its dev-only tile).
8. **Manifest.** One `FOREGROUND_SERVICE` / `POST_NOTIFICATIONS` declaration; two foreground
   services: `RecordingService` (microphone, AUD-05) and `ModelDownloadService` (dataSync, MDL-02).
   AUD-05's Play-policy test now pins exactly those two and the two typed permissions.

## Repairs of main's web-editor merges (b548206)
- `recording_screen.dart` (merge 3e4a545): both CallGuard `IconButton`s concatenated, a bracket
  left open → analyzer errors. Fixed by this branch's resolution (AUD wrappers + both dev buttons,
  localized).
- `app/pubspec.yaml` (merge c6c582b): `mustache_template` dropped → EXP-01 template engine did not
  compile. Restored (2.0.5 exact).
- `docs/privacy-audit.md`: AUD-01's `record` dependency row dropped. Restored.
- `packages/vv_native/lib/vv_native.dart` + `vv_bindings.g.dart` (merge e6caf9a): STT-02's
  `loadBackends` / `describeBackends` / `dynamicBackends` / `cpuBackendStatus`, the `VV_GPU_*` and
  extra `VV_E_*` exports and the `vv_backends_*` bindings were lost (header still declared them →
  `check_bindings` red). Restored and regenerated.

## Consequences
- One code path to verify on devices for GPU enablement (STT and LLM share the module loader,
  the rules and the crash sentinel). GPU benchmarks for Android now use the DL build
  (`docs/test-plans/device/LLM-03.md` B2/B3 updated).
- Follow-ups (not done here — new work): production wiring of the STT/LLM engines and of
  `schemaGrammarConverterProvider`; a provider for `LlmPlanGate.entitlements` once tiering is
  wired; one perf-core implementation (`vv_threads.h` vs `vv_cpu.c`); localise the AUD-05
  notification texts in `features/recording/domain/recording_indicator.dart`; `FOREGROUND_SERVICE_DATA_SYNC`
  Play declaration text (MDL-02/REL-05); GPU identity probe for `GpuInfo` on Android.
