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
  - AC1: ⏳ test: [LLM-07/AC1]; device: docs/test-plans/device/LLM-07.md
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

## Rework
- **Agent:** Claude Code · **Branch:** task/LLM-07-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged).
- **Issue 1 (residency acquisition returned before asynchronous STT disposal):**
  - Reproduced first: new `app/test/unit/extraction/model_residency_test.dart` (`[LLM-07/AC1] residency awaits asynchronous disposal`). Against the unchanged code the two race tests failed — an STT unloader blocked on a `Completer` still let `LlmService` call `runtime.load` (`rt.loads` non-empty, "LLM loaded while STT resident"), and `acquire` returned with a 20 ms-delayed unloader still running (the verifier's repro).
  - Fix (`app/lib/features/extraction/domain/model_residency.dart`): `register` takes `FutureOr<void> Function()`; `acquire`/`releaseAll` return `Future<void>`, **await** every unloader and are serialized through one chain, so concurrent transitions never mark two kinds resident. A kind is dropped from `loaded` only after its unloader completed; if the unloader throws, the old kind stays marked resident, the new kind is not added, and `ModelResidencyException(stillResident, errorType)` (content-free) is thrown.
  - `LlmService.onBeforeLoad` is now `FutureOr<void> Function()?` and is awaited inside the single in-flight `_loading` future (a concurrent request joins the same load instead of starting a second one); `ModelResidencyException` maps to retryable `OutOfMemoryFailure` (pipeline backs off and retries; the LLM is never loaded over a resident STT). After the wait the backend choice is re-checked (`_forceCpu` ⇒ CPU) so the extra wait cannot start GPU work after backgrounding.
  - `ActiveSttEngine` registers its async `unload` directly (was `() => unawaited(unload())`) and awaits `residency.acquire(stt)`; an LLM that cannot be freed returns `Err(OutOfMemoryFailure)`.
  - Regression tests (all `[LLM-07/AC1]`): async disposal gates the LLM load; `acquire` awaits a delayed unloader; throwing disposal ⇒ exception, STT still resident, `LlmService.generate` returns `OutOfMemoryFailure` with zero loads, then succeeds once disposal works; concurrent `acquire(llm)`/`acquire(stt)` serialized (no overlap sampled every 1 ms, unloads in order); `releaseAll` awaits. Existing residency tests in `device_tiering_test.dart`/`active_engines_test.dart` now await `acquire`.
  - Mutation check (2026-10-14): removed the `await` on the unloader in `ModelResidency._unload` → `model_residency_test.dart` 5 of 5 failed; restored → 5 passed.
- **Overlap note:** FND-05 (HeavyModelGate release failures) and LLM-04 (background/load race in `LlmService`) are reworked on separate branches; this branch touches `llm_service.dart` only at `onBeforeLoad`/`_load`/`_loadFailure`. `pipeline_orchestrator.dart` is unchanged.
- **Still pending:** AC1 device rows in `docs/test-plans/device/LLM-07.md` (iPhone 11, 4 GB Android, memory-warning and tier-probe rows) stay ⏳.
- **Gates (host, macOS, 2026-10-15):** `dart format --set-exit-if-changed` 0 changed (639 files) · `flutter analyze` and `dart analyze --fatal-infos` 0 issues · `check_codegen.sh` clean (no diff) · `check_recording_policy.sh` OK · `check_egress.sh` OK · `pytest tools/ci/tests` 90 passed, 1 skipped · `tasks.py validate` 0 problems · `flutter test`: 1360 passed, 52 skipped, 2 failed — both wall-clock thresholds unrelated to this change, run while the host load average was ~57 (parallel rework agents): `[APP-02/AC1]` search < 200 ms (passed on rerun) and `[AUD-08/AC1]` tap→mic < 300 ms (675 ms under load; record screen does not use `ModelResidency`). The verifier should rerun both on an idle host. Focused suites (`model_residency_test`, `device_tiering_test`, `active_engines_test`, `background_guard_test`): 30 passed.
