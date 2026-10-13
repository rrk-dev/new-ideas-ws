# APP-03 — Settings Screen

**Workstream:** App UX | **Phase:** 3–4 | **Size:** S | **Depends on:** FND-04 | **Source:** Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-licensing-iap, vv-privacy-security, vv-local-database, vv-testing

## Goal
Central place for all configuration.

## Scope
- [ ] Audio: input device, AGC/noise suppression, auto-pause on silence, audio retention.
- [ ] Processing: auto-process after recording, charge-only processing, diarization default, models (link to MDL-03).
- [ ] Export: vault targets, routing rules, filename pattern, collision mode.
- [ ] Privacy & security: app lock, encryption info, data retention, export diagnostics, delete all data.
- [ ] License: status, restore purchases, enter enterprise license.
- [ ] About: version, open-source & model licenses (SEC-05).

## Acceptance Criteria
- Every setting persisted and covered by a widget test; managed (enterprise-locked) settings shown as read-only (LIC-04).
