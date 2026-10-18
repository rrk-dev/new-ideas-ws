# LIC-04 — Enterprise Managed Configuration (MDM)

**Workstream:** Licensing | **Phase:** 4+ | **Size:** M | **Depends on:** LIC-03, PRF-08 | **Source:** §7 (Pre-configured enterprise templates) + Gap
**Status:** review
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-privacy-security, vv-extraction-profiles, vv-testing

## Goal
IT admins push license, profiles, templates and policies via MDM.

## Scope
- [x] iOS Managed App Configuration (`com.apple.configuration.managed` UserDefaults); Android Managed Configurations (`app_restrictions.xml`).
- [~] Keys (names per `vv-licensing-iap`): `license`, `profile_packs` (base64 or file — **no URL fetch**), `allowed_target_kinds`, `audio_retention_days`, `network_disabled` (sideload-only models), `lock_settings`, `force_app_lock`, `disable_custom_models`, `force_consent_confirmation`, `max_recording_minutes` (stricter only). Encryption is always on — no key for it.
- [x] Settings UI shows managed values as locked (APP-03).
- [x] Document config schema for admins.
- [x] Managed config can make recording **stricter** only (e.g. force consent confirmation, shorter max duration). No key may start a recording remotely, hide recording indicators, disable the call guard or consent steps (SEC-09).

## Acceptance Criteria
- Tested with an MDM (e.g., Jamf/Intune test tenant or Android Test DPC); policies enforced on device.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/LIC-04-mdm-config · **Date:** 2026-10-18
- **Summary:** Pure-Dart `ManagedConfig` parser (never throws, key names only in `ignoredKeys`, stricter-only) behind channel `vaultvoice/managed_config` with readers for iOS/macOS (`UserDefaults` `com.apple.configuration.managed`) and Android (`RestrictionsManager`, `app_restrictions.xml`, runtime change receiver). Wired into `ManagedSettingsSource` (locked tiles, forced app lock/offline/retention `days_N`), the network gateway/downloader, custom-model entitlement, the recording cap (min of managed and default), forced consent confirmation, vault target kinds (`ManagedVaultFolderAccess`), the licence (LIC-03 port) and signed profile packs (PRF-08; org key set from the installed licence, unsigned packs rejected). Settings shows a managed-status tile. No network additions; no content logged. Docs: `docs/mdm-config.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [LIC-04/AC1]; device: docs/test-plans/device/LIC-04.md; artifact: docs/mdm-config.md
- **Unverified:** macOS legacy managed-config delivery before macOS 27 (declarative `com.apple.configuration.app.managed`/`AppConfig` is documented for macOS 27.0+/iOS 18.4+ only); Android `bundle_array`/`multi-select` rendering in MDM consoles; Android build is CI-only.
- **Deferred:** file variant of `profile_packs` (base64 only) → follow-up; vault-folder policy is not applied until the config is first read.
- **Follow-ups:** LIC-03 Codex items (persist licence, import file) remain out of scope.
