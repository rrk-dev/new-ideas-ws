# APP-07 — Lumen brand: name and logo

**Workstream:** App UX | **Phase:** 4 | **Size:** M | **Depends on:** — | **Source:** User request 2026-10-16
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-ci-release, vv-testing

## Goal
Rename the user-visible product from "VaultVoice" to **Lumen** and give it a logo and app icons, without breaking installs or data.

## Scope
- [x] Logo concept (calm, minimal, teal): SVG master in `design/brand/` (icon mark and wordmark, light and dark variants).
- [x] App icons generated from the master for iOS (dev, prod), macOS and Android (adaptive foreground and monochrome), plus the in-app launch image.
- [x] Display name "Lumen" (dev flavor "Lumen Dev") in Info.plists, `APP_DISPLAY_NAME`, Android `app_name`, macOS bundle name, and permission strings.
- [x] All user-visible strings in the ARB files and generated l10n use "Lumen"; docs, store listing and licence attribution text updated.
- [x] Wordmark/logo widget used on onboarding and About.
- [x] Unchanged by design: bundle/application ids, Dart package name `vaultvoice`, method-channel names, DB/file paths, `.vvprofile`/`.vvlicense` extensions, signing keys.

## Acceptance Criteria
- No user-visible "VaultVoice" string remains in `app/lib`, ARB files, platform manifests or store docs (a test scans for it; the allowlist covers the identifiers above).
- Every icon size required by iOS, macOS and Android is present and non-empty, generated reproducibly from `design/brand/` by a script.
- An existing install upgrades in place and keeps its data (bundle ids and storage paths unchanged; checked by test of path constants).
- The logo has a contrast ratio of at least 4.5:1 against its background in light and dark variants.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/APP-07-lumen-brand · **Date:** 2026-10-16
- **Summary:** Lumen brand: SVG masters in `design/brand/` (icon, mark, wordmark; light and dark), `tools/brand/make_icons.py` (Pillow only) generates iOS AppIcon/-dev/-prod (RGB, no alpha; dev has a DEV band), LaunchImage, macOS AppIcon, Android legacy + adaptive foreground + monochrome mipmaps and the flutter_launcher_icons sources. User-visible text renamed in ARBs and regenerated l10n, plists, `APP_DISPLAY_NAME`, Android `app_name`, templates, privacy policy, licence text, fastlane/store metadata and docs. `LumenMark`/`LumenWordmark` (`app/lib/core/branding/lumen_logo.dart`, CustomPainter) shown on onboarding step 1 and in Settings → About. Ids, package name, channels, paths, extensions, keys, `VaultVoice/1` User-Agent, crash-report headers and the TestFlight group name are unchanged (allowlisted).
- **Acceptance evidence:**
  - AC1: ✅ test: [APP-07/AC1]
  - AC2: ✅ test: [APP-07/AC2]
  - AC3: ✅ test: [APP-07/AC3]
  - AC4: ✅ test: [APP-07/AC4]
- **Decisions:** none (no technology choice; Pillow renderer chosen because libcairo is not installed).
- **Follow-ups:** none
