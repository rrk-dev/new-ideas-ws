# LLM-07 — Memory Management & Device Capability Tiering

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-04, STT-03 | **Source:** Gap (3B Q4 ≈ 2–2.5 GB RAM; iPhone 11 has 4 GB, many Android budget devices 4–6 GB)
**Status:** in-progress
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


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ⏳ iPhone 11/4 GB Android 30-minute full-pipeline/background runs remain documented but unrun. ❌ ModelResidency cannot enforce the no-overlap invariant for the real asynchronous STT unloader.
  - AC2: ✅ tagged mocked-profile tests assert <5/5–7/≥7 GiB boundaries, tier contexts, Free/Pro defaults and cache corruption recovery. Memory planning/pressure tests also passed.
- **Mutation sanity check:** Changed the Low-tier boundary from 5 GiB to 3 GiB: `[LLM-07/AC2]` tier/default/cache tests failed; restored with git checkout.
- **Adversarial checks:** Ran memory estimate/headroom/refusal/halved-context/pressure tests. External Flutter repro registered an async STT unloader delayed 20 ms, acquired STT then LLM: acquire returned with STT still resident. This matches WhisperSttEngine.unload (Future<void>), whereas existing test only increments a synchronous counter.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/LLM-07.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:**
  1. `ModelResidency.register` takes void Function() and acquire synchronously calls the unloader, drops STT from bookkeeping and marks LLM loaded without awaiting disposal. Dart accepts an async unloader at this boundary and silently discards its Future. The actual WhisperSttEngine.unload is asynchronous; an LLM may load before native STT destruction finishes. Use an awaited asynchronous residency transition and await it before native load; add a delayed-disposal regression test.
