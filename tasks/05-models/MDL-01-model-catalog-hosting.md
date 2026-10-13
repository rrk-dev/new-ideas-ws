# MDL-01 — Model Catalog Manifest & Hosting

**Workstream:** Model Delivery | **Phase:** 2 | **Size:** M | **Depends on:** FND-02 | **Source:** §5 Phase 2 (dynamic model downloader) + Gap (hosting / integrity / "zero bytes to cloud" contradiction)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-model-delivery, vv-privacy-security, vv-decision-records, vv-flutter-architecture, vv-testing

## Goal
A trustworthy source of model files that keeps the privacy promise: the only network traffic is anonymous, user-initiated model downloads.

## Scope
- [ ] Signed JSON manifest: model id, type (stt/llm/vad/diarization), tier, size, SHA-256, min RAM, license id, URL(s), min app version.
- [ ] Sign manifest with Ed25519; public key pinned in app; reject unsigned/modified manifests.
- [ ] Hosting choice: own CDN/object storage (recommended) vs Hugging Face direct links (license + availability risk). Mirrors for resilience.
- [ ] No cookies, no auth, no identifiers in download requests; document exactly what the server sees (IP, User-Agent) for the privacy page.
- [ ] Bundled fallback manifest in the app for first launch.

## Acceptance Criteria
- Tampered manifest or model hash is rejected in tests.
- Network traffic capture during download shows only manifest + model requests with no identifying headers.

## Notes
- This task builds the catalog format, signing, hosting and tooling. The actual model entries are
  added by STT-07 (Whisper variants) and LLM-08 (LLM defaults); seed the catalog with
  `ggml-tiny.en` + one small GGUF so MDL-02 can be built and tested.
