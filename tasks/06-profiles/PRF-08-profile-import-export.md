# PRF-08 — Profile & Template Import / Export

**Workstream:** Profiles | **Phase:** 3–4 | **Size:** S | **Depends on:** PRF-01, EXP-01, LIC-03 | **Source:** §7 (Enterprise pre-configured extraction templates) + Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-privacy-security, vv-licensing-iap, vv-markdown-vault-export, vv-testing

## Goal
Share profiles (with their templates) as files, and let enterprises distribute pre-configured packs.

## Scope
- [ ] `.vvprofile` bundle (zip: `profile.yaml`, `template.mustache`, `manifest.json`, optional `signature.ed25519`) — per `vv-extraction-profiles`.
- [ ] Register the file type: iOS exported UTI (`com.vaultvoice.profile`, `CFBundleDocumentTypes`) and Android intent filter for `.vvprofile`.
- [ ] Export via share sheet; import via file picker / "Open in".
- [ ] Signed enterprise packs: verify org signature (LIC-03 key); mark as managed / non-editable.
- [ ] Conflict handling on import (same id, newer version).

## Acceptance Criteria
- Round-trip export → import on the other platform produces an identical profile.
- Tampered signed pack is rejected.
