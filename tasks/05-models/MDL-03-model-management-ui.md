# MDL-03 — Model Management Screen

**Workstream:** Model Delivery | **Phase:** 3 | **Size:** S | **Depends on:** MDL-02, LLM-07, LIC-01 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-model-delivery, vv-flutter-architecture, vv-licensing-iap, vv-testing

## Goal
Users see installed/available models, disk usage and can swap or delete them.

## Scope
- [x] List models by type with size, tier, Pro badge, device-compatibility indicator.
- [x] Download / delete / set-as-default actions.
- [x] Total storage used by models, audio, transcripts.
- [x] Update notification when a newer model version appears in the manifest.

## Acceptance Criteria
- Deleting the active model prompts for a replacement and never leaves the pipeline without a usable model.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/MDL-03-model-management (stacked on
  task/APP-01-onboarding: reuses its `model_state_providers.dart` and `startModelDownloads`)
  · **Date:** 2026-10-14
- **Summary:** `ModelsScreen` (`app/lib/features/models/presentation/models_screen.dart`,
  route Settings › Models) lists every catalog model grouped by type with size + version, plan
  badge (Pro/Enterprise), "In use", "Recommended" (LLM-07 bundle), device-fit warning
  (`min_ram_mb` vs probed RAM), download progress, plan lock (`AccessLevel` from LIC-01:
  `readOnly` installed-but-not-selectable, `disabled` → "Requires Pro" via `ensureFeature`
  paywall). Actions: Download / Resume / Update (MDL-02 plan → size, mobile-data and low-power
  consent, Android 13+ notification prompt once before the first download), Pause / Cancel, "Use
  this model" (`models.active_stt` / `models.active_llm`, the keys FND-11's production engine factory reads), Delete. Domain
  `domain/model_management.dart`: `buildModelEntries`, `resolveActiveModel` (choice → recommended
  → first usable; never a locked/incompatible model), `planDeletion` (free / needs replacement /
  blocked), `isNewerVersion`. `ModelManager.delete` switches the active model to the chosen
  replacement *before* `ModelInstaller.uninstall` (row, then `models/<id>/`) and refuses to
  delete the last usable model of a pipeline type. Storage totals from the DB
  (`watchStorageUsage`: installed model sizes, audio chunk bytes, UTF-8 transcript text). Update
  notice when the catalog lists a newer version; "Check for model updates" refreshes the signed
  catalog (`ActiveCatalog.refresh`). `network_disabled` hides downloads + update check and shows
  an offline notice; the MDL-04 import tile moved here (section "Import from files") with the
  "Advanced: custom models" toggle shown only when `Feature.sideloadCustomModel` is enabled.
  `activeModelIdsProvider` exposes the model per type for the pipeline wiring.
- **Acceptance evidence:**
  - AC1: ✅ test: [MDL-03/AC1]
- **Decisions:** none (no technology choice). PRODUCT-DECISIONs: the last usable STT/LLM model
  cannot be deleted (the skill's alternative "confirm STT disabled" is not offered); update
  notice is in-app only (no background catalog polling, no OS notification) and the catalog is
  only fetched when the user taps "Check for model updates".
- **Follow-ups:** wiring note below; no new task.
- **Privacy checklist:** no new network code (catalog refresh uses the existing
  `CatalogRepository.refresh` through the gateway); no logging added; no new dependencies;
  storage totals are sizes only.

## Follow-ups
- **Wiring note (FND-11, not on main when this was written):** FND-11's engine factory reads
  `models.active_stt` / `models.active_llm` (then the LLM-07 tier default); MDL-03 writes exactly
  those keys (`ActiveModelKeys`) with a `models_installed` id. `activeModelIdsProvider` gives the
  same resolution (choice → recommended → first usable) for UI/pipeline use.
- **Note:** the Settings › Models tile does not yet show an "update available" badge.
