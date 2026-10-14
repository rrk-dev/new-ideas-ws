# LLM-07 — Memory Management & Device Capability Tiering

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-04, STT-03 | **Source:** Gap (3B Q4 ≈ 2–2.5 GB RAM; iPhone 11 has 4 GB, many Android budget devices 4–6 GB)
**Status:** review
**Skills:** vv-task-workflow, vv-llm-inference, vv-background-execution, vv-ffi-bridge, vv-flutter-architecture, vv-whisper-stt, vv-testing

## Goal
The app picks models and settings each device can actually run, and never gets OOM-killed mid-job.

## Scope
- [~] Device capability probe: total/available RAM, SoC/GPU, OS version, thermal state; cache a capability tier (Low / Mid / High). Done: `vv_device_memory` (iOS `os_proc_available_memory`, macOS vm stats, Linux/Android `/proc/meminfo`), GPU devices / perf cores / CPU guard (LLM-02/03), OS version → `NativeDeviceProfileProbe`; `DeviceTierCache` (keyed by RAM + OS version). The thermal-state platform source (Swift `ProcessInfo.thermalState` / Kotlin `PowerManager`) is deferred → LLM-11 (field `ThermalState.unknown` until then; Runner/MainActivity are owned by other groups).
- [x] Tier → default models (e.g., Low: whisper-base + Llama-3.2-1B/Gemma-2B Q4; High: whisper-small/turbo + 3B Q4_K_M) and context size. `tierForRam` (Low < 5 GiB, Mid 5–7, High ≥ 7), `defaultContextFor` (4096 / 6144 / 8192), `defaultsFor(device, catalog, plan)` picks the largest catalog model per type that is recommended for the tier, fits `min_ram_mb` and the plan (Free ⇒ 1B class only, via `LlmPlanGate`; wire to LIC-01 `EntitlementService.has(Feature.largeLlm)`).
- [x] Never load STT and LLM simultaneously; explicit unload between pipeline steps. `ModelResidency` (acquire unloads the other kind) + `LlmService.onBeforeLoad`; pre-load check `planLlmLoad` (available ≥ estimate × 1.2, halves n_ctx down to 2048, else refuses with `OutOfMemoryFailure`) via `LlmService.loadGate`; estimate counts full weights (CPU/Android path).
- [x] React to memory warnings (iOS `didReceiveMemoryWarning`, Android `onTrimMemory`): checkpoint and unload. `LlmMemoryPressureObserver` (`didHaveMemoryPressure`, which Flutter raises for both) → `LlmService.onMemoryPressure()`: stop at the next token, unload, return `OutOfMemoryFailure` (pipeline retries from its checkpoint), next load at half context.
- [x] Block or warn when a user selects a model too large for the device. `assessModelFit` → `ok` / `warn` (> 40% of RAM at n_ctx 2048) / `block` (> 60%, or `min_ram_mb` > RAM); the model-management UI (MDL-*) shows it.

## Acceptance Criteria
- Full pipeline on iPhone 11 and a 4 GB Android device completes without being killed on a 30-min recording.
- Tier detection unit-tested with mocked device profiles.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-07-memory-tiering (stacked on task/LLM-05-structured-output) · **Date:** 2026-10-13
- **Summary:** Native `vv_device_memory` (`native/bridge/vv_llama.cpp`) + Dart `VvNative.deviceMemory`; app `features/extraction/domain/device_tiering.dart` (DeviceProfile, tiers, tier × plan defaults, `LlmPlanGate` placeholder for LIC-01), `memory_planner.dart` (estimate, `planLlmLoad`, `assessModelFit`), `model_residency.dart`; `LlmService` gained `loadGate`, `onBeforeLoad`, `onMemoryPressure`, `effectiveContextSize`; `data/device_profile_probe.dart` (probe + `DeviceTierCache`), `data/memory_pressure_observer.dart`; dev wiring in `data/dev_llm_engine.dart`. Tests `test/unit/extraction/device_tiering_test.dart`.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/LLM-07.md
  - AC2: ✅ test: [LLM-07/AC2]
- **Decisions:** thresholds above (memory math from vv-llm-inference; fit 40% / 60% chosen conservatively — revise from the AC1 device rows)
- **Follow-ups:** see below

## Follow-ups
- LLM-11 (proposed, not filed): thermal-state source (Pigeon: iOS `ProcessInfo.thermalState` + Android `PowerManager.getCurrentThermalStatus`/listener) feeding `DeviceProfile.thermal` and the pipeline's `DeviceConditions` (vv-background-execution).
- Production wiring of `llmEngineProvider` with `defaultsFor` + active catalog model (MDL-*), LIC-01 `EntitlementService` as `LlmPlanGate`, and one `ModelResidency` shared with the STT engine (STT-03 / FND-05 owners).
- Android backend selection will move to STT-02's `vv_backends_*` / `core/platform/backend_policy.dart` (coordinator decision); this task only consumes `LlmBackendChoice`.
