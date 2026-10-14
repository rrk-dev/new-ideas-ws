# APP-01 — Onboarding & Permission Flow

**Workstream:** App UX | **Phase:** 2–4 | **Size:** M | **Depends on:** MDL-02, EXP-03, EXP-04, LLM-07 | **Source:** Gap (first-launch experience implied by model downloader)
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-model-delivery, vv-markdown-vault-export, vv-privacy-security, vv-pipeline-orchestrator, vv-audio-capture, vv-testing

## Goal
New users go from install to first exported note in under 5 minutes, understanding the privacy model.

## Scope
- [x] Privacy explainer screen: "everything stays on your device; the only network use is downloading models".
- [x] Device capability check → recommended model bundle with sizes (LLM-07, MDL-01).
- [x] Model download with progress; allow exploring/recording while downloading (queue processing until ready).
- [x] Permission priming before OS prompts: microphone (requested just-in-time on the first Record tap, never at launch), notifications, folder selection.
- [x] Show the recording-consent explainer built in SEC-07 (APP-01 only places it in the flow) and the "VaultVoice never records calls" statement.
- [x] Pick default vault folder (or "keep in app for now").
- [x] Optional guided first recording.

## Acceptance Criteria
- Usability test: 5 of 5 participants complete onboarding without help.
- Denying any permission leaves the app functional with clear recovery path.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/APP-01-onboarding · **Date:** 2026-10-14
- **Summary:** First-launch flow `app/lib/features/onboarding/` — `OnboardingScreen` (route
  `/onboarding`, outside the tab shell; `appRouter` redirects there until
  `onboarding.completed`, unknown state never redirects): privacy explainer → recording-consent
  explainer (`RecordingConsentExplainer`, SEC-07 placement incl. "never records phone or VoIP
  calls"; acknowledgement required, stored as `consent.first_run_ack_at`) → permission priming
  (microphone only explained; notifications asked via `LocalNotifier.requestPermission`, sets
  `notifications.permission_asked`; denial → `PermissionDeniedNotice` with "Open settings") →
  recommended models (`recommendBundle` over LLM-07 `defaultsFor` + MDL-01 catalog; device probe
  `deviceProfileProvider`, unknown device = 4 GB assumption) with sizes and live download progress
  (`startModelDownloads`: size up front, mobile-data consent with "always allow" →
  `models.allow_cellular_downloads`, low-power confirmation, offline/no-space messages; Continue
  never blocked; `network_disabled` hides downloads and shows the MDL-04 import tile) → default
  vault folder (`pickAndSaveVaultFolder`, shared with Settings › Vault folders) or "Keep notes in
  the app for now" → ready (guided first recording opens the Record tab; "Explore first" opens the
  Library). Queue-until-ready: `ModelInstallWaker` (started in `ProcessingServicesHost`) resolves
  `waiting(model_missing)` jobs whenever a new model is installed. Microphone priming for the first
  Record tap: `primeMicrophonePermission` (once, before the OS prompt; "Not now" requests nothing).
  Native "Open settings": `AppSettingsPlugin.kt` (Android) + channel in `AppDelegate.swift` (iOS),
  Dart `core/platform/app_settings_launcher.dart`. Strings in `app_en.arb`; onboarding row in the
  accessibility test + per-step a11y test; golden `test/golden/goldens/onboarding_privacy_*.png`.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/APP-01.md
  - AC2: ⏳ test: [APP-01/AC2]; device: docs/test-plans/device/APP-01.md
- **Decisions:** none (no technology choice). PRODUCT-DECISIONs: consent wording is placeholder
  pending SEC-07/legal review; "Keep notes in the app" creates no vault target (EXP-05 app-local
  fallback); unknown device → smallest models; mobile-data decline does not auto-resume on Wi-Fi.
- **Follow-ups:** see below (AUD-08 wiring note; no new task).
- **Privacy checklist:** no network code added (downloads go through the existing MDL-02
  downloader/gateway); no logging added; no new dependencies; the microphone is never opened or
  requested by onboarding (recording policy check passes); new settings keys hold no content.

## Follow-ups
- **AUD-08 note:** the Record button should `await primeMicrophonePermission(context, ref)`
  (`features/onboarding/presentation/permission_priming.dart`) before its first
  `RecordingController.start`, and show `PermissionDeniedNotice.microphone()` when start fails with
  `PermissionFailure('microphone')`.
- **SEC-07 note:** replace the body of `RecordingConsentExplainer` with the reviewed wording; the
  first-run acknowledgement is stored as `consent.first_run_ack_at` (`OnboardingKeys`).
- **Test note:** widget tests that pump `App()` with an empty `FakeSettingsStore` now land on
  `/onboarding`; seed `{OnboardingKeys.completed: true}` (see `accessibility_test.dart`).
