# LLM-07 — Memory Management & Device Capability Tiering

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-04, STT-03 | **Source:** Gap (3B Q4 ≈ 2–2.5 GB RAM; iPhone 11 has 4 GB, many Android budget devices 4–6 GB)
**Status:** todo
**Skills:** vv-task-workflow, vv-llm-inference, vv-background-execution, vv-ffi-bridge, vv-flutter-architecture, vv-whisper-stt, vv-testing

## Goal
The app picks models and settings each device can actually run, and never gets OOM-killed mid-job.

## Scope
- [ ] Device capability probe: total/available RAM, SoC/GPU, OS version, thermal state; cache a capability tier (Low / Mid / High).
- [ ] Tier → default models (e.g., Low: whisper-base + Llama-3.2-1B/Gemma-2B Q4; High: whisper-small/turbo + 3B Q4_K_M) and context size.
- [ ] Never load STT and LLM simultaneously; explicit unload between pipeline steps.
- [ ] React to memory warnings (iOS `didReceiveMemoryWarning`, Android `onTrimMemory`): checkpoint and unload.
- [ ] Block or warn when a user selects a model too large for the device.

## Acceptance Criteria
- Full pipeline on iPhone 11 and a 4 GB Android device completes without being killed on a 30-min recording.
- Tier detection unit-tested with mocked device profiles.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).
