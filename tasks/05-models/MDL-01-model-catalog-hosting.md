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

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[MDL-01/AC1]` (Dart `catalog_verifier_test.dart`, `catalog_repository_test.dart`, and `tools/model-catalog/tests/test_catalog.py` — 35 passed across catalog/release/crash pytest, and the Dart files inside the 785). Tests reject a one-byte catalog change, a swapped model hash, a forged/zeroed/foreign signature, rollback, unknown schema, oversized body, and a newer `min_app_version`. Checked the CLI test fails when `catalog.py` skips the Ed25519 verify (tampered catalog then returns 0).
  - AC2: ✅ re-ran `[MDL-01/AC2]`. Asserts every catalog request is HTTPS GET, host is the primary or mirror, path is only `catalog.json` or `catalog.json.sig`, no query or userinfo, redirects not followed, and headers are exactly `User-Agent: VaultVoice/1` and `Accept: */*`. Proxy-capture device row is blank.
- **Adversarial checks:** Non-allowlisted host returns `EgressDeniedFailure` and sends nothing. Bundled catalog stays when the remote signature fails. No cookies, auth, or install id in `kAnonymousRequestHeaders`. Signing private key is not in the repo (keygen writes a file or reads env; REL-01's private-key scan also passes). `tasks.py verify MDL-01 --run` short-circuits on the pending AC2 row; tagged tests passed in the suites above.
- **Skill/rule compliance:** Fetch goes through `NetworkGateway` and `kModelHosts`. Ed25519 + SHA-256, at most two pinned keys. ADR-MDL-01 is Proposed (CDN domain and production key are owner decisions), which matches the follow-up. No recording code and no content logs.
- **Issues found:** none
- **Pending for done:** AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/MDL-01.md has no PASS result with a date; dependency FND-02 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
