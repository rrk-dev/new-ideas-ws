# APP-07 — Lumen brand: name and logo

**Workstream:** App UX | **Phase:** 4 | **Size:** M | **Depends on:** — | **Source:** User request 2026-10-16
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-ci-release, vv-testing

## Goal
Rename the user-visible product from "VaultVoice" to **Lumen** and give it a logo and app icons, without breaking installs or data.

## Scope
- [ ] Logo concept (calm, minimal, teal): SVG master in `design/brand/` (icon mark and wordmark, light and dark variants).
- [ ] App icons generated from the master for iOS (dev, prod), macOS and Android (adaptive foreground and monochrome), plus the in-app launch image.
- [ ] Display name "Lumen" (dev flavor "Lumen Dev") in Info.plists, `APP_DISPLAY_NAME`, Android `app_name`, macOS bundle name, and permission strings.
- [ ] All user-visible strings in the ARB files and generated l10n use "Lumen"; docs, store listing and licence attribution text updated.
- [ ] Wordmark/logo widget used on onboarding and About.
- [ ] Unchanged by design: bundle/application ids, Dart package name `vaultvoice`, method-channel names, DB/file paths, `.vvprofile`/`.vvlicense` extensions, signing keys.

## Acceptance Criteria
- No user-visible "VaultVoice" string remains in `app/lib`, ARB files, platform manifests or store docs (a test scans for it; the allowlist covers the identifiers above).
- Every icon size required by iOS, macOS and Android is present and non-empty, generated reproducibly from `design/brand/` by a script.
- An existing install upgrades in place and keeps its data (bundle ids and storage paths unchanged; checked by test of path constants).
- The logo has a contrast ratio of at least 4.5:1 against its background in light and dark variants.
