# PRF-08 — Profile & Template Import / Export

**Workstream:** Profiles | **Phase:** 3–4 | **Size:** S | **Depends on:** PRF-01, EXP-01, LIC-03 | **Source:** §7 (Enterprise pre-configured extraction templates) + Gap
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-privacy-security, vv-licensing-iap, vv-markdown-vault-export, vv-testing

## Goal
Share profiles (with their templates) as files, and let enterprises distribute pre-configured packs.

## Scope
- [x] `.vvprofile` bundle (zip: `profile.yaml`, `template.mustache`, `manifest.json`, optional `signature.ed25519`) — per `vv-extraction-profiles`.
- [x] Register the file type: iOS exported UTI (`com.vaultvoice.profile`, `CFBundleDocumentTypes`) and Android intent filter for `.vvprofile`.
- [x] Export via share sheet; import via file picker / "Open in". [~] "Open in" delivery of the opened file to the importer deferred → PRF-11 (needs MainActivity/AppDelegate intent/URL handling; the file types are registered)
- [x] Signed enterprise packs: verify org signature (LIC-03 key); mark as managed / non-editable.
- [x] Conflict handling on import (same id, newer version).

## Acceptance Criteria
- Round-trip export → import on the other platform produces an identical profile.
- Tampered signed pack is rejected.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/PRF-08-profile-import-export (stacked on task/PRF-07-custom-profile-editor →
  task/PRF-02-system-prompt-builder; uses the Profiles tab/editor) · **Date:** 2026-10-14
- **Summary:** `app/lib/features/profiles/domain/profile_bundle.dart` (`ProfileBundleCodec` encode/decode, deterministic zip,
  manifest with sha256 per file, Ed25519 signature over `manifest.json`, `OrgProfileKey`, `Ed25519BundleSigner`, limits
  2 MB bundle / 1 MB file / 4 entries, zip-slip and unexpected-name rejection, format check, profile + template validation).
  `profiles/data/profile_transfer_service.dart` (export with the bound template — stored row, built-in asset or generated;
  `inspect` → `ImportReady` (new / update) or `ImportRefused` (invalid bundle, id taken, older, already installed, not
  entitled); `install` keeps the version, managed packs become `enterprise` read-only, never shadows a built-in template).
  `profile_transfer_providers.dart` (`orgProfileKeysProvider` — LIC-03 placeholder, trusts no key; file picker; export dir;
  service with `Feature.customProfiles` / `Feature.managedProfiles`). UI: Profiles tab "Import profile" (confirm dialog,
  localized refusals) and editor "Export profile" (share sheet). File type: iOS `UTExportedTypeDeclarations`
  `com.vaultvoice.profile` + `CFBundleDocumentTypes`; Android VIEW intent filters (custom MIME, `.vvprofile` path pattern).
  Format documented in `docs/profile-spec.md` → "`.vvprofile` bundles"; device rows `docs/test-plans/device/PRF-08.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [PRF-08/AC1]; device: docs/test-plans/device/PRF-08.md
  - AC2: ⏳ test: [PRF-08/AC2]; device: docs/test-plans/device/PRF-08.md
- **Decisions:** no ADR (no new dependency: `archive`, `crypto`, `cryptography`, `file_selector` already reviewed).
  PRODUCT-DECISION: no built-in trusted org key — signed packs are refused until LIC-03 supplies the license's
  `org_profile_pubkey`. PRODUCT-DECISION: importing unsigned (user) bundles needs Pro (`customProfiles`), managed packs need
  Enterprise (`managedProfiles`); export is always allowed. `profile.yaml` is written as indented JSON (valid YAML; the
  `yaml` package has no emitter). Gates: format clean, analyze 0 issues, `flutter test` 830 passed / 24 skipped,
  pytest 66, recording-policy / egress / codegen OK.
- **Devices needed:** iPhone (iOS 17+) and Pixel-class Android 14+ for the cross-platform round trip; LIC-03 for AC2 on device.
- **Follow-ups:** see below.

## Follow-ups
- PRF-11 (proposed): "Open in" — deliver a tapped `.vvprofile` (Android `ACTION_VIEW` content URI in MainActivity, iOS
  `application(_:open:options:)` / scene `openURLContexts`) to `importProfileBundle` through a small Pigeon/MethodChannel.
- LIC-03: override `orgProfileKeysProvider` with the enterprise license's `org_profile_pubkey`; `tools/licensing/` can sign
  packs with `Ed25519BundleSigner` (same envelope as here).
- LIC-04: MDM `profile_packs` (base64 list) → `ProfileTransferService.inspect/install` at launch.
