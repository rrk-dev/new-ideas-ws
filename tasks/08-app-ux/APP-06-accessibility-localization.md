# APP-06 — Accessibility & Localization Scaffolding

**Workstream:** App UX | **Phase:** 4 | **Size:** S | **Depends on:** FND-02 | **Source:** Gap
**Status:** review
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
## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ · analyze ✅ · tests ✅ (780 passed, 29 skipped; coverage not re-measured locally, CI test job gates ≥80% and is green) · native smoke n/a (no native/bridge change) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51 of ci, commit 67b6fcf, completed successfully; run 50 also succeeded)
- **Acceptance criteria:**
  - AC1: ✅ host re-ran `[APP-06/AC1]`. For every current route (Record, Library, processing queue, recording status, Profiles, Settings, vault folders, routing rules, Models) in light and dark: `labeledTapTargetGuideline`, Android and iOS tap targets, `textContrastGuideline`, and 200% text scale with no overflow after a scroll. Tab labels and the queue indicator have semantics labels. Theme pairs used for status text are ≥ 4.5:1. Status is text plus icon. Device rows in `docs/test-plans/device/APP-06.md` (VoiceOver and TalkBack through record → export) are blank (⏳). The Record tab is still `PlaceholderScreen`; the checklist's record-button steps are not executable until AUD-08, which the task's scope note and Follow-ups already assign. That does not make the host checks hollow
  - AC2: ✅ re-ran `[APP-06/AC2]`. The scanner walks `lib/core/routing`, `lib/core/widgets`, `lib/app.dart`, and every `features/*/presentation` dart file, and the self-test shows `Text('Hello')`, `title: const Text("Save")`, tooltip/semantics/message literals fail the scan while l10n lookups, comments, and symbol-only strings do not. Mutation: inserted `Text('Hello verifier')` in `recording_screen.dart`; the scan failed; restored
- **Adversarial checks:** searched presentation sources for multiline `Text(` / `SelectableText(` literals the line scanner would miss; the only hit is on the allowlisted CallGuard debug screen and is an interpolation. Unsupported-locale step is on the device checklist (English ARB only, as scoped). No new network host.
- **Skill/rule compliance:** `flutter_localizations` + ARB as required by `vv-flutter-architecture`. Dev-only debug screens are allowlisted with reasons. No credentials or certificates.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/APP-06.md has no PASS result with a date; dependency FND-02 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
