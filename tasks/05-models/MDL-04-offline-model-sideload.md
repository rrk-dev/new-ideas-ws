# MDL-04 — Offline / Air-Gapped Model Import

**Workstream:** Model Delivery | **Phase:** 3–4 | **Size:** S | **Depends on:** MDL-01, MDL-02 | **Source:** Gap (regulated / defense users may not allow any downloads)
**Status:** review
**Skills:** vv-task-workflow, vv-model-delivery, vv-privacy-security, vv-testing

## Goal
Install models from a local file (USB, AirDrop, MDM-pushed file) with zero network.

## Scope
- [x] Import `.gguf`/`.bin` + signed sidecar manifest via file picker.
- [x] Verify signature and hash identical to online path; reject unknown models unless "advanced: custom model" is enabled (Pro).
- [x] Optional enterprise setting: disable all network access (LIC-04 managed config).

## Acceptance Criteria
- With airplane mode on, a fresh install can be fully provisioned via sideload and run the full pipeline.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/MDL-04-offline-model-import (stacked on
  task/MDL-02-model-downloader) · **Date:** 2026-10-13
- **Summary:** `ModelImporter` (`app/lib/features/models/data/model_importer.dart`): signed
  import of model file + `<id>.json` + `<id>.json.sig` via `verifySingleModelManifest`
  (`domain/model_manifest.dart` — the unchanged `CatalogVerifier`, exactly one model), size
  check, staging in `models/.partial/` (move picker copies, else copy with free-space check),
  SHA-256 in an isolate (`verifyModelFileInIsolate`, same as MDL-02), install through the shared
  `ModelInstaller` (extracted from the downloader). Unknown files are rejected unless
  "Advanced: custom model" (`models.advanced_custom_model`) **and** `CustomModelEntitlement`
  allow it — **placeholder entitlement denies until LIC-01** (`customModelEntitlementProvider`);
  custom GGUFs pass `checkGgufHeader` (magic, version 2/3, bounded tensor/KV counts that fit the
  file) and install as `custom-<sha16>/custom.gguf` (no user file name stored). File picker
  `file_selector` 1.1.0 (`model_import_providers.dart`), `ModelImportTile` in Settings with the
  custom-model warning. `network_disabled` setting (`kNetworkDisabledKey`): `NetworkGateway`
  checks it before every request (fail closed); downloader plan reports `offline`;
  `networkDisabledProvider` for the UI. `catalog.py build --only <id>` produces the manifest
  (+ pytest). Docs: ADR-MDL-04, privacy audit (dependency + network_disabled), device rows.
- **Acceptance evidence:**
  - AC1: ⏳ test: [MDL-04/AC1]; device: docs/test-plans/device/MDL-04.md
- **Decisions:** ADR-MDL-04-offline-model-import (Proposed)
- **Follow-ups:** notes below (LIC-01, LIC-04, MDL-03)
- **Privacy checklist:** no network code added outside the gateway (`check_egress.sh` OK);
  `network_disabled` blocks all egress; no content logged, picked file names never stored or
  logged; new dependency `file_selector` reviewed in `docs/privacy-audit.md`; imported models
  under `vv/models/` with backup exclusion; recording policy check passes.

## Follow-ups
- **LIC-01 note:** override `customModelEntitlementProvider`
  (`features/models/data/model_import_providers.dart`) with the real Pro check (PLACEHOLDER
  denies today). PRODUCT-DECISION: confirm custom models are Pro (task says so).
- **LIC-04 note:** map managed config `network_disabled` to the `network_disabled` settings key
  (or override the gateway's check); MDM may only make it stricter.
- **MDL-03 note:** hide download actions while `networkDisabledProvider` is true, show the
  import tile on the model screen, and add the "Advanced: custom model" toggle
  (`models.advanced_custom_model`) only when the entitlement allows it.
