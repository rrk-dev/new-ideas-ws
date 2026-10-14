# APP-01 — Onboarding & Permission Flow

**Workstream:** App UX | **Phase:** 2–4 | **Size:** M | **Depends on:** MDL-02, EXP-03, EXP-04, LLM-07 | **Source:** Gap (first-launch experience implied by model downloader)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-model-delivery, vv-markdown-vault-export, vv-privacy-security, vv-pipeline-orchestrator, vv-audio-capture, vv-testing

## Goal
New users go from install to first exported note in under 5 minutes, understanding the privacy model.

## Scope
- [ ] Privacy explainer screen: "everything stays on your device; the only network use is downloading models".
- [ ] Device capability check → recommended model bundle with sizes (LLM-07, MDL-01).
- [ ] Model download with progress; allow exploring/recording while downloading (queue processing until ready).
- [ ] Permission priming before OS prompts: microphone (requested just-in-time on the first Record tap, never at launch), notifications, folder selection.
- [ ] Show the recording-consent explainer built in SEC-07 (APP-01 only places it in the flow) and the "VaultVoice never records calls" statement.
- [ ] Pick default vault folder (or "keep in app for now").
- [ ] Optional guided first recording.

## Acceptance Criteria
- Usability test: 5 of 5 participants complete onboarding without help.
- Denying any permission leaves the app functional with clear recovery path.
