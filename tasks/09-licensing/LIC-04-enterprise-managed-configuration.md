# LIC-04 — Enterprise Managed Configuration (MDM)

**Workstream:** Licensing | **Phase:** 4+ | **Size:** M | **Depends on:** LIC-03, PRF-08 | **Source:** §7 (Pre-configured enterprise templates) + Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-licensing-iap, vv-flutter-architecture, vv-privacy-security, vv-extraction-profiles, vv-testing

## Goal
IT admins push license, profiles, templates and policies via MDM.

## Scope
- [ ] iOS Managed App Configuration (`com.apple.configuration.managed` UserDefaults); Android Managed Configurations (`app_restrictions.xml`).
- [ ] Keys (names per `vv-licensing-iap`): `license`, `profile_packs` (base64 or file — **no URL fetch**), `allowed_target_kinds`, `audio_retention_days`, `network_disabled` (sideload-only models), `lock_settings`, `force_app_lock`, `disable_custom_models`, `force_consent_confirmation`, `max_recording_minutes` (stricter only). Encryption is always on — no key for it.
- [ ] Settings UI shows managed values as locked (APP-03).
- [ ] Document config schema for admins.
- [ ] Managed config can make recording **stricter** only (e.g. force consent confirmation, shorter max duration). No key may start a recording remotely, hide recording indicators, disable the call guard or consent steps (SEC-09).

## Acceptance Criteria
- Tested with an MDM (e.g., Jamf/Intune test tenant or Android Test DPC); policies enforced on device.
