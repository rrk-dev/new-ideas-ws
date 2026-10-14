# Device verification — LLM-07 Memory management & device tiering

Host-verified: `[LLM-07/AC2]` tier detection, tier × plan defaults, pre-load memory check, model
fit, STT/LLM residency and memory-pressure handling (`app/test/unit/extraction/device_tiering_test.dart`,
fakes); `vv_device_memory` (ctest `vv_llm_engine`, M3 Pro: total 18432 MiB).

**AC1 needs the full pipeline** (recording → STT → extraction → export), which is assembled by
FND-05 / STT-* / PRF-* / EXP-*; this task provides the memory pieces it must use:
`ModelResidency` (unload STT before LLM), `planLlmLoad` load gate, `defaultsFor` tier defaults,
`LlmService.onMemoryPressure` via `LlmMemoryPressureObserver`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-07/AC1] | 1. Install the dev build with the tier-default models (Low tier: 1B Q4_K_M, n_ctx 4096). 2. Record (or import) a 30-min meeting. 3. Let the pipeline run to the exported note with the screen on, then repeat with the app backgrounded after STT starts. 4. Watch Settings → Privacy → Analytics (JetsamEvent) / Xcode console | Note exported both times; no JetsamEvent for the app; diagnostics metrics show STT and LLM never loaded at the same time (peak RSS during extract ≈ LLM estimate, not STT + LLM) | iPhone 11 (VV-IOS-11, 4 GB) | iOS 16+ | | | |
| [LLM-07/AC1] | Same on the 4 GB Android phone (`adb shell dumpsys meminfo com.vaultvoice.vaultvoice.dev` during extract; `adb logcat -b events | grep am_kill`) | Note exported; no `lowmemorykiller`/`am_kill` for the app | VV-AND-4G (4 GB MediaTek + Mali) | Android 12+ | | | |
| [LLM-07/AC1] | Dev build with `--dart-define=VV_DEV_LLM_MODEL=…`; Settings → LLM debug → long generation; Xcode → Debug → Simulate Memory Warning (Android: `adb shell am send-trim-memory com.vaultvoice.vaultvoice.dev COMPLETE`) | Status "failed: out of memory" within ~1 token; next Generate reloads with half the context; no crash | iPhone (any) + Android (any) | — | | | |
| [LLM-07/AC1] | Run the probe on each matrix device (debug screen or `fvm flutter test integration_test/llm_engine_test.dart` logs) and record `vv_device_memory` total / available | Tier matches the matrix table (iPhone 11 → low, 6 GB → mid, 8 GB → high) | all QA-05 devices | — | | | |
