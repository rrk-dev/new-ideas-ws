# APP-06 — Accessibility & Localization Scaffolding

**Workstream:** App UX | **Phase:** 4 | **Size:** S | **Depends on:** FND-02 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
App is usable with screen readers and ready for translation.

## Scope
- [ ] `flutter_localizations` + ARB files; all strings externalized (English at launch).
- [ ] Semantics labels for all controls (record button state announced).
- [ ] Dynamic type / text scaling up to 200% without layout breakage.
- [ ] Color contrast WCAG AA; no color-only status indicators.

## Acceptance Criteria
- VoiceOver and TalkBack can complete record → export flow.
- No hard-coded user-facing strings (lint rule / test).
