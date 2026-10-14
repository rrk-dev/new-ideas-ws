# APP-03 — Settings Screen

**Workstream:** App UX | **Phase:** 3–4 | **Size:** S | **Depends on:** FND-04 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-licensing-iap, vv-privacy-security, vv-local-database, vv-testing

## Goal
Central place for all configuration.

## Scope
- [x] Audio: input device, AGC/noise suppression, auto-pause on silence, audio retention.
- [x] Processing: auto-process after recording, charge-only processing, diarization default, models (link to MDL-03).
- [x] Export: vault targets, routing rules, filename pattern, collision mode.
- [x] Privacy & security: app lock, encryption info, data retention, export diagnostics, delete all data.
- [x] License: status, restore purchases, enter enterprise license.
- [x] About: version, open-source & model licenses (SEC-05).

## Acceptance Criteria
- Every setting persisted and covered by a widget test; managed (enterprise-locked) settings shown as read-only (LIC-04).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/APP-03-settings (stacked on task/APP-04-processing-status) · **Date:** 2026-10-13
- **Summary:** Declarative registry `app/lib/features/settings/domain/setting_definitions.dart`
  (`AppSettings.all`: 15 typed settings — toggle / choice / validated text — with defaults; keys in
  `setting_keys.dart`), ports in `settings_ports.dart` (`SettingsStore`, `ManagedSettingsSource` +
  `ManagedSettings` {values, locked} for LIC-04, `LicenseSettingsPort` for LIC-01/02/03,
  `DataWiper` for SEC-04 — defaults refuse instead of pretending). `data/drift_settings_store.dart`
  persists in the FND-04 `settings` table. `presentation/settings_providers.dart` (effective value =
  managed › stored › default; `SettingsWriter` refuses managed keys and invalid values),
  `setting_tiles.dart` (switch / choice dialog / text dialog; managed → disabled + lock +
  "Managed by your organization"), `settings_screen.dart` with all six sections: Audio (input
  device, AGC, noise suppression, auto-pause, audio retention), Processing (auto-process,
  charge-only, diarization default, Models link → placeholder route until MDL-03), Export (vault
  folders add/remove via EXP-03/04 pickers, routing rules list, filename pattern, collision mode),
  Privacy & security (app lock + timeout, truthful encryption status from `databaseCipherProvider`,
  transcript retention, APP-04 notification toggles, FND-07 "Export diagnostics", delete all data),
  License (status, restore purchases, enter enterprise license), About (version `kAppVersion`,
  "Open-source & model licenses" = `showLicensePage` + `core/licenses/bundled_licenses.dart`
  registering whisper.cpp/ggml, llama.cpp, Whisper weights, Qwen2.5 in `bootstrap`). Typed routes
  `/settings/models|vault-folders|routing-rules`. `StatusMessage` moved to `core/widgets`;
  `UnsupportedFeatureFailure` added to `core/errors`.
- **Acceptance evidence:**
  - AC1: ✅ test: [APP-03/AC1]
- **Decisions:** no ADR (no technology choice). PRODUCT-DECISION defaults flagged in
  `setting_definitions.dart`: audio and transcript retention default "keep until I delete",
  diarization default off, lock timeout 1 min.
- **Follow-ups:** see below.

## Follow-ups
- LIC-01/LIC-02/LIC-03: implement `LicenseSettingsPort` (status, restore, enterprise install) and
  gate "Add folder" with `Feature.multiTarget` (Free = one vault target).
- LIC-04: implement `ManagedSettingsSource` mapping MDM keys (`force_app_lock`,
  `audio_retention_days`, `lock_settings` …) to `SettingKeys`.
- SEC-04: implement `DataWiper` and apply the retention settings; SEC-03: enforce
  `security.app_lock` / `security.lock_timeout`; SEC-01: encryption tile turns "On" automatically.
- AUD-xx / FND-05 scheduling / EXP-02 / EXP-05: read the audio, processing and export settings
  (keys in `SettingKeys`); EXP-05 owns the routing-rule editor; MDL-03 replaces the Models placeholder.
