# MDL-04 — Offline / Air-Gapped Model Import

**Workstream:** Model Delivery | **Phase:** 3–4 | **Size:** S | **Depends on:** MDL-01, MDL-02 | **Source:** Gap (regulated / defense users may not allow any downloads)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-model-delivery, vv-privacy-security, vv-testing

## Goal
Install models from a local file (USB, AirDrop, MDM-pushed file) with zero network.

## Scope
- [ ] Import `.gguf`/`.bin` + signed sidecar manifest via file picker.
- [ ] Verify signature and hash identical to online path; reject unknown models unless "advanced: custom model" is enabled (Pro).
- [ ] Optional enterprise setting: disable all network access (LIC-04 managed config).

## Acceptance Criteria
- With airplane mode on, a fresh install can be fully provisioned via sideload and run the full pipeline.
