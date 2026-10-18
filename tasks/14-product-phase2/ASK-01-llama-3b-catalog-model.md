# ASK-01 — Add Llama 3.2 3B Instruct to the model catalog

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** MDL-01, MDL-02, LLM-07, LLM-08, SEC-05, LIC-01 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes needs the 3B model); ADR-LLM-08 (3B is the expected Mid/High default, not yet measured)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-model-delivery, vv-llm-inference, vv-benchmark-eval, vv-privacy-security, vv-licensing-iap, vv-testing

## Goal
A pinned, hash-verified Llama 3.2 3B Instruct Q4_K_M model is offered in the signed catalog for devices that can run it, with measured quality, memory and speed numbers.

## Scope
- [ ] Add the model to `tools/model-catalog/models.json` (same source family as the existing 1B entry, a pinned revision, SHA-256 and size read from the real file, never typed from memory), regenerate and re-sign the catalog per `tools/model-catalog/README.md`, and update `app/assets/catalog/catalog.json`. Production signing-key handling stays an owner action; do not commit a private key.
- [ ] Licence: record "Llama 3.2 Community License" and the "Built with Llama" attribution in the catalog entry and `docs/licenses.md`/SEC-05 artefacts the same way the 1B entry does; confirm the AUP pass-through text is shown where models are listed.
- [ ] `min_ram_mb` and `recommended_device_tiers` from measurement (LLM-07 tiers: Low < 5 GiB, Mid 5–7, High ≥ 7), not from the ADR's expectation. State clearly which tiers are not recommended.
- [ ] Gating: `tier` and `isLargeLlm` already treat models above `kSmallLlmMaxBytes` (1.2 GB) as `Feature.largeLlm` (Pro in `kFeatureMatrix`). Keep that behaviour and flag the Free-vs-Pro question for ask-your-notes as `// PRODUCT-DECISION` (decided in LIC-05); do not change the matrix here.
- [ ] Verify the download works end to end on the corporate network used by the team (the Cisco proxy blocked a Qwen host earlier): record the exact hosts contacted, confirm each is already in `kModelHosts` / `kModelRedirectHosts`, and add none without the documented observation procedure in `model_hosts.dart`.
- [ ] Measure with PRF-09 on all three built-in profiles (and the new TPL profiles when available) against the 1B baseline: quality, schema validity, hallucination, decode tokens/s, peak RSS, load time. Add the numbers to `docs/models.md` and update ADR-LLM-08 (3B row becomes measured or stays "expected").
- [ ] Download, verify and delete work through the existing Models screen (MDL-03) and offline import (MDL-04) for this model; storage size warning is shown before download.

## Acceptance Criteria
- Catalog JSON validates against `catalog.schema.json`, the signature verifies with the production-format verifier test, and the hash/size of the entry match the downloaded file (`[ASK-01/AC1]`, `tools/model-catalog/tests`).
- All URLs of the entry use hosts already allowlisted; `check_egress.sh` and the catalog host tests pass (`[ASK-01/AC2]`).
- A measured 1B-vs-3B comparison table is committed (artifact) with schema validity ≥ 90% and hallucination ≤ 15% required before the 3B can be marked recommended for any tier; otherwise it ships as "not recommended" and ASK-03 is blocked.
- On a physical Mid-tier and High-tier device the model loads, extracts and unloads without an OOM, and STT/LLM residency is never simultaneous (device rows, `docs/test-plans/device/ASK-01.md`; ⏳ until run).
- Licence/attribution text for the model appears in the app's licences screen and in `docs/licenses.md` (test + artifact).

## Notes
- Qwen models stay out: the ADR rejects Qwen2.5-3B's research licence, and one Qwen host is blocked on our network.
