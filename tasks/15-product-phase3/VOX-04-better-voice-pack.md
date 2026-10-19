# VOX-04 — Optional better-voice pack (Piper or Kokoro)

**Workstream:** Product Phase 3 | **Phase:** 6 | **Size:** L | **Depends on:** VOX-01, VOX-02, MDL-02, FND-10 | **Source:** User request 2026-10-18 (Phase 3, not started)
**Status:** todo
**Skills:** vv-task-workflow, vv-native-build, vv-ffi-bridge, vv-model-delivery, vv-privacy-security, vv-ci-release, vv-testing

## Goal
An optional downloadable neural voice gives better, consistent speech across platforms, if VOX-01 judged its licence, size and cost acceptable.

## Scope
- [ ] Only if ADR-VOX-01 is Accepted for a neural engine: build it into `native/bridge` (C ABI, no C++ across FFI, no direct third-party Dart native package).
- [ ] Voice pack in the signed model catalog (MDL-01/02) with licence shown and checksum verified; never bundled in the app.
- [ ] Settings choice between OS voice and the pack; memory rule respected (never resident with STT or the LLM).
- [ ] Native binary size and CI size gate updated; licence file added to `docs/licenses.md`.

## Acceptance Criteria
- A user can download, select and remove the voice pack, and speech uses it offline.
- Neural TTS is never loaded while Whisper or the LLM is resident (test).
- App binary growth stays within the budget recorded in ADR-VOX-01.
- `docs/licenses.md` lists every new component and voice licence.

## Notes
Do not implement yet. May be dropped if OS voices are good enough.
