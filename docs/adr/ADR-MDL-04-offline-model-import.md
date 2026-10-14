# ADR-MDL-04 — Offline model import: manifest format, file picker, custom GGUF gate

- **Status:** Proposed (implemented + host-tested; airplane-mode device run pending —
  `docs/test-plans/device/MDL-04.md`; custom-model tier is a product decision)
- **Date:** 2026-10-13
- **Task:** MDL-04
- **Deciders:** Claude Code (implementer); pending independent verifier + owner (tier)
- **Supersedes:** —

## Context
Regulated / air-gapped users must provision models with zero network (USB, AirDrop, MDM file
push). The import must be exactly as trustworthy as a download (ADR-MDL-01, ADR-MDL-02): pinned
Ed25519 signature, exact size + SHA-256, same atomic install. Unsigned "custom" GGUFs are a Pro
"advanced" option and are untrusted parser input (SEC-08 threat "malicious GGUF").
`network_disabled` (user offline mode / MDM managed config, LIC-04) must stop *all* egress.

## Decisions
1. **Single-model manifest = a schema-1 catalog document with exactly one model**
   (`catalog.py build --only <id>` → `<id>.json`, `catalog.py sign` → `<id>.json.sig`). The app
   verifies it with the unchanged `CatalogVerifier` (same keys, envelope, schema, size caps,
   app-version check) and then requires `models.length == 1`. No separate format, no second
   parser. No rollback floor for imports (an air-gapped device may hold an older manifest; the
   file is still pinned by its hash). Options considered: a new `{"model": …}` document (second
   parser + schema to keep in sync — rejected); signing the model file itself (multi-GB
   signature verification on device, no metadata — rejected).
2. **File picker: `file_selector` 1.1.0** (flutter.dev, BSD-3-Clause, released 2025-11-21;
   platform packages `file_selector_android` 0.5.2+11 (2026-09-11) and `file_selector_ios`
   0.5.3+6 (2026-08-28)). Source checked: no network/telemetry code; Android copies the picked
   `content://` document into `cacheDir/<uuid>/`, iOS uses `UIDocumentPickerViewController` in
   import mode (copy in the app tmp). The importer **moves** those app-private copies into
   `models/.partial/` (same volume) instead of copying a 2 GB file twice. Alternative
   `file_picker` (community, larger surface incl. web/desktop extras) — not needed. Writing our
   own Pigeon pickers — more native code for no gain.
3. **Custom GGUF gate:** requires the `models.advanced_custom_model` setting **and**
   `CustomModelEntitlement.allowsCustomModels()`; the default implementation is a
   **placeholder that denies** until LIC-01 overrides `customModelEntitlementProvider`. Before
   anything is installed: GGUF magic, version ∈ {2, 3}, `0 < n_tensors ≤ 65536`,
   `n_kv ≤ 65536`, and `24 + n_tensors × 24 ≤ file size` (layout per ggml `docs/gguf.md`). The
   model is installed as `models/custom-<sha256[0:16]>/custom.gguf` — the user's file name is
   never stored or logged. llama.cpp still does full validation when loading (LLM-xx); fuzzing
   the GGUF load path is SEC-08.
4. **`network_disabled`:** `NetworkGateway` consults the setting before **every** request
   (`get`, `getStream`, `authorize`); unreadable setting → refused (fail closed). The downloader
   reports `offline` in its plan so the UI hides downloads (MDL-03), and the import tile in
   Settings works without network.

## Consequences
- New dependency `file_selector` 1.1.0 (recorded in `docs/privacy-audit.md`).
- PRODUCT-DECISION: which tier unlocks custom models (task says Pro) and the warning text.
- MDM key name: `network_disabled` in the `settings` table; LIC-04 maps managed config to it.
