# APP-06 — Accessibility & Localization Scaffolding

**Workstream:** App UX | **Phase:** 4 | **Size:** S | **Depends on:** FND-02 | **Source:** Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
App is usable with screen readers and ready for translation.

## Scope
- [x] `flutter_localizations` + ARB files; all strings externalized (English at launch).
- [x] Semantics labels for all controls (record button state announced). *(All existing controls are labelled and checked by `labeledTapTargetGuideline`; the record button itself does not exist yet — AUD-08 builds it and must announce its state, see Follow-ups.)*
- [x] Dynamic type / text scaling up to 200% without layout breakage.
- [x] Color contrast WCAG AA; no color-only status indicators.

## Acceptance Criteria
- VoiceOver and TalkBack can complete record → export flow.
- No hard-coded user-facing strings (lint rule / test).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/APP-06-a11y-l10n (stacked on task/APP-03-settings) · **Date:** 2026-10-13
- **Summary:** `flutter_localizations` + `intl` (version pinned by the SDK), `generate: true`,
  `app/l10n.yaml` → `lib/core/l10n/arb/app_en.arb` (156 keys, ICU plurals/placeholders) →
  generated `lib/core/l10n/gen/` (committed, excluded from analysis); `lib/core/l10n/l10n.dart`
  (`context.l10n` with English fallback, `l10nFor(locale)` for notifications). `App` and the golden
  helper install the delegates. Mechanical externalisation of every user-facing string in
  `lib/core/routing`, `lib/core/widgets` and every `features/*/presentation` file (incl. FND-02 tab
  bar/placeholders, FND-07 diagnostics, SEC-09 Record placeholder, APP-03/APP-04 screens and the
  notification texts / Android channel name). Tests: `test/unit/l10n/hardcoded_strings_test.dart`
  (scanner + self-test + unused-key check), `test/widget/accessibility_test.dart` (9 routed
  screens × light/dark × 4 guidelines, 200 % text without overflow, tab bar/indicator semantics,
  theme contrast ratios ≥ 4.5:1). Status is shown with text + icon (never colour only).
  Contributor rules in `CONTRIBUTING.md` → "User-facing text, localization and accessibility".
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/APP-06.md; test: [APP-06/AC1]
  - AC2: ✅ test: [APP-06/AC2]
- **Decisions:** no ADR (Flutter's standard gen-l10n named by `vv-flutter-architecture`).
  Allowlisted from the string scan: `kAppName` (product name) and the dev-flavor-only SEC-09
  `call_guard_debug_screen.dart`.
- **Follow-ups:** see below.

## Follow-ups
- AUD-08: the record button must expose `Semantics(button: true, label: …, value: <state/elapsed>)`
  and announce state changes (`SemanticsService.announce`); add its screen to
  `test/widget/accessibility_test.dart`. `stillRecordingText` (AUD-04/05 notification,
  `recording/domain/recording_limits.dart`) should move to an ARB key when the notification lands.
- Every new screen (APP-01/02/05, MDL-03, PRF-xx, EXP-07) adds a row to the accessibility test.
