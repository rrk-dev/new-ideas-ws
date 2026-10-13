# MDL-01 — Model Catalog Manifest & Hosting

**Workstream:** Model Delivery | **Phase:** 2 | **Size:** M | **Depends on:** FND-02 | **Source:** §5 Phase 2 (dynamic model downloader) + Gap (hosting / integrity / "zero bytes to cloud" contradiction)
**Status:** review
**Skills:** vv-task-workflow, vv-model-delivery, vv-privacy-security, vv-decision-records, vv-flutter-architecture, vv-testing

## Goal
A trustworthy source of model files that keeps the privacy promise: the only network traffic is anonymous, user-initiated model downloads.

## Scope
- [x] Signed JSON manifest: model id, type (stt/llm/vad/diarization), tier, size, SHA-256, min RAM, license id, URL(s), min app version.
- [x] Sign manifest with Ed25519; public key pinned in app; reject unsigned/modified manifests.
- [x] Hosting choice: own CDN/object storage (recommended) vs Hugging Face direct links (license + availability risk). Mirrors for resilience.
- [x] No cookies, no auth, no identifiers in download requests; document exactly what the server sees (IP, User-Agent) for the privacy page.
- [x] Bundled fallback manifest in the app for first launch.

## Acceptance Criteria
- Tampered manifest or model hash is rejected in tests.
- Network traffic capture during download shows only manifest + model requests with no identifying headers.

## Notes
- This task builds the catalog format, signing, hosting and tooling. The actual model entries are
  added by STT-07 (Whisper variants) and LLM-08 (LLM defaults); seed the catalog with
  `ggml-tiny.en` + one small GGUF so MDL-02 can be built and tested.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/MDL-01-model-catalog · **Date:** 2026-10-12
- **Summary:** Schema-1 catalog (`tools/model-catalog/catalog.schema.json`) with Dart models +
  validation (`app/lib/features/models/domain/model_catalog.dart`), Ed25519 verifier with ≤ 2
  pinned keys, rollback floor, unknown-schema / app-version / size-cap rejection
  (`catalog_verifier.dart`, `catalog_keys.dart`), streaming size + SHA-256 model-file check
  (`model_file_verifier.dart`), `CatalogRepository` (bundled signed fallback
  `app/assets/catalog/catalog.json(.sig)` + refresh via `NetworkGateway` with mirrors and
  anonymous headers), gateway allowlist `core/network/model_hosts.dart`. Python CLI
  `tools/model-catalog/catalog.py` (keygen/pubkey/hash/build/sign/verify; key from file or env,
  never in repo) + `models.json` source. Seed: `whisper-tiny.en` (size/sha256 computed from a
  local download) and `qwen2.5-0.5b-instruct-q4_k_m` (size/sha256 from HF LFS metadata at a
  pinned revision; local download blocked by proxy → MDL-05). Docs: ADR-MDL-01,
  `docs/privacy-audit.md` (what the CDN sees, dependency review), device row for the proxy capture.
- **Acceptance evidence:**
  - AC1: ✅ test: [MDL-01/AC1]
  - AC2: ⏳ test: [MDL-01/AC2]; device: docs/test-plans/device/MDL-01.md
- **Decisions:** ADR-MDL-01-model-hosting (Proposed — CDN provider/domain and production
  signing key are owner decisions)
- **Follow-ups:** MDL-05 (proposed), MDL-02 note
- **Privacy checklist:** no network code outside the gateway (`check_egress.sh` OK); no logging
  added; new deps `cryptography` 2.9.0 / `crypto` 3.0.7 reviewed in `docs/privacy-audit.md`; no
  new stored files; no recording code touched.

## Follow-ups
- **MDL-05 (proposed) — Catalog state persistence & production key:** persist last accepted
  `issued_at` + the last verified remote catalog bytes (FND-04 DB / app support dir) behind
  `catalogStateStoreProvider`; owner generates the production Ed25519 key offline, replaces
  `vv-catalog-dev-2026a` in `catalog_keys.dart`, re-signs; re-hash the GGUF seed by download
  (`catalog.py hash`) once the network allows it.
- **MDL-02 note:** Hugging Face `resolve` URLs 302-redirect to `*.cdn.hf.co`; the gateway does
  not follow redirects — the downloader must re-check each redirect target against the allowlist
  (or the files must be mirrored on our CDN). Reuse `kAnonymousRequestHeaders` and
  `verifyModelBytes`.
