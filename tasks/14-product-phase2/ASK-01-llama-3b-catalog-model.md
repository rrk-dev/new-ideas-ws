# ASK-01 — Add Llama 3.2 3B Instruct to the model catalog

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** MDL-01, MDL-02, LLM-07, LLM-08, SEC-05, LIC-01 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes needs the 3B model); ADR-LLM-08 (3B is the expected Mid/High default, not yet measured)
**Status:** review
**Skills:** vv-task-workflow, vv-model-delivery, vv-llm-inference, vv-benchmark-eval, vv-privacy-security, vv-licensing-iap, vv-testing

## Goal
A pinned, hash-verified Llama 3.2 3B Instruct Q4_K_M model is offered in the signed catalog for devices that can run it, with measured quality, memory and speed numbers.

## Scope
- [x] Add the model to `tools/model-catalog/models.json` (same source family as the existing 1B entry, a pinned revision, SHA-256 and size read from the real file, never typed from memory), regenerate and re-sign the catalog per `tools/model-catalog/README.md`, and update `app/assets/catalog/catalog.json`. Production signing-key handling stays an owner action; do not commit a private key.
- [x] Licence: record "Llama 3.2 Community License" and the "Built with Llama" attribution in the catalog entry and `docs/licenses.md`/SEC-05 artefacts the same way the 1B entry does; confirm the AUP pass-through text is shown where models are listed.
- [x] `min_ram_mb` and `recommended_device_tiers` from measurement (LLM-07 tiers: Low < 5 GiB, Mid 5–7, High ≥ 7), not from the ADR's expectation. State clearly which tiers are not recommended.
- [x] Gating: `tier` and `isLargeLlm` already treat models above `kSmallLlmMaxBytes` (1.2 GB) as `Feature.largeLlm` (Pro in `kFeatureMatrix`). Keep that behaviour and flag the Free-vs-Pro question for ask-your-notes as `// PRODUCT-DECISION` (decided in LIC-05); do not change the matrix here.
- [x] ⏳ (hosts verified from this host; corporate network row is a device row) Verify the download works end to end on the corporate network used by the team (the Cisco proxy blocked a Qwen host earlier): record the exact hosts contacted, confirm each is already in `kModelHosts` / `kModelRedirectHosts`, and add none without the documented observation procedure in `model_hosts.dart`.
- [x] Measure with PRF-09 on all three built-in profiles (and the new TPL profiles when available) against the 1B baseline: quality, schema validity, hallucination, decode tokens/s, peak RSS, load time. Add the numbers to `docs/models.md` and update ADR-LLM-08 (3B row becomes measured or stays "expected").
- [x] ⏳ (widget tests done; physical-device rows pending) Download, verify and delete work through the existing Models screen (MDL-03) and offline import (MDL-04) for this model; storage size warning is shown before download.

## Acceptance Criteria
- Catalog JSON validates against `catalog.schema.json`, the signature verifies with the production-format verifier test, and the hash/size of the entry match the downloaded file (`[ASK-01/AC1]`, `tools/model-catalog/tests`).
- All URLs of the entry use hosts already allowlisted; `check_egress.sh` and the catalog host tests pass (`[ASK-01/AC2]`).
- A measured 1B-vs-3B comparison table is committed (artifact) with schema validity ≥ 90% and hallucination ≤ 15% required before the 3B can be marked recommended for any tier; otherwise it ships as "not recommended" and ASK-03 is blocked.
- On a physical Mid-tier and High-tier device the model loads, extracts and unloads without an OOM, and STT/LLM residency is never simultaneous (device rows, `docs/test-plans/device/ASK-01.md`; ⏳ until run).
- Licence/attribution text for the model appears in the app's licences screen and in `docs/licenses.md` (test + artifact).

## Notes
- Qwen models stay out: the ADR rejects Qwen2.5-3B's research licence, and one Qwen host is blocked on our network.

## Completion Notes
- **Summary:** Source: bartowski/Llama-3.2-3B-Instruct-GGUF @ `5ab33fa94d1d04e903623ae72c95d1696f09f9e8`, file downloaded and hashed (sha256 `6c1a2b41…28ff`, 2019377696 bytes = HF LFS oid). Signed with the dev key only; production re-sign is an owner action. Tier `pro` kept in the catalog (PRODUCT-DECISION, LIC-05); personal builds unlock all, so it is free today. No new network host. Recommended for High only (peak RSS 3718 MiB > Mid budget 2800 MiB). Added: AUP text on Llama model cards, confirmation dialog for downloads ≥ 1 GB, licence registry entry.

- **Agent:** GitHub Copilot CLI · **Branch:** task/ASK-01-llama-3b-catalog-model · **Date:** 2026-10-17
- **Acceptance evidence:**
  - AC1: ✅ test: [ASK-01/AC1]
  - AC2: ✅ test: [ASK-01/AC2]; device: docs/test-plans/device/ASK-01.md
  - AC3: ✅ artifact: tools/bench/results/2026-10-17-ask01-1b-vs-3b.md
  - AC4: ⏳ device: docs/test-plans/device/ASK-01.md
  - AC5: ✅ test: [ASK-01/AC5]; artifact: docs/licenses.md
- **Notes:** the AC1 hash test runs with `VV_ASK01_MODEL_FILE` set to the downloaded GGUF; the AC2 corporate-network row is ⏳ in the device plan; the 3B passes the AC3 gates and is recommended for High only.

## Follow-ups
- ASK-03: evaluate the 3B on its own Q&A eval; quality is profile-dependent (engineering/interview worse than 1B).
- Owner: re-sign the catalog with the production key; CDN host is still a placeholder.
- Decided 2026-10-17: the 3B is explicit-selection only (never an automatic default); ASK-03 may select it explicitly.
