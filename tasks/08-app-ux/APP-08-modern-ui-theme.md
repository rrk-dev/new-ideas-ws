# APP-08 — Modern UI: design system and screen restyle

**Workstream:** App UX | **Phase:** 4 | **Size:** L | **Depends on:** APP-07 | **Source:** User request 2026-10-16
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
A calm, minimal, modern look (soft neutrals, one teal accent, generous spacing) applied through one design system so every screen inherits it.

## Scope
- [x] Design tokens in `lib/core/theme`: colour scheme (light and dark), type scale, spacing, radii, elevation, motion; no hard-coded colours or sizes in features.
- [x] Themed components: buttons, cards, list tiles, inputs, chips, app/nav bars, dialogs, bottom sheets, progress, empty and error states.
- [x] Restyle onboarding, Record (large primary record control, live level meter), Library, note detail, Process/Models, Settings.
- [x] Respect system light/dark, text scaling to 200%, reduced motion, and 48 dp touch targets.
- [x] Goldens regenerated on Linux for changed screens.

## Acceptance Criteria
- Light and dark themes are defined once in `lib/core/theme`; a test fails if a feature file uses a raw `Color(0x…)` literal outside the theme.
- Text and control contrast meets WCAG AA (4.5:1 body, 3:1 large) in both themes, verified by a test over the colour tokens.
- All primary screens render without overflow at text scale 2.0 (widget tests).
- Screen goldens for onboarding, Record, Library, Settings and Models exist in light and dark.
- No behaviour change: existing tests pass.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/APP-08-modern-ui · **Date:** 2026-10-16
- **Summary:** Design system in `lib/core/theme` (`app_tokens.dart`: spacing/radius/elevation/size/motion tokens, light+dark palettes from the Lumen teal, `LumenExtras`; `app_theme.dart`: M3 ColorScheme light/dark, type scale, component themes). Shared widgets in `lib/core/widgets` (`LumenCard`, `SectionHeader`, `EmptyState`, `PrimaryActionButton`; `StatusMessage` delegates to `EmptyState`). Restyled: onboarding, Record (teal circular record button, calm pill level meter), Library (card list, themed search, empty state), Settings (grouped section cards), Models/Process/note detail/paywall/transcript via inherited component themes. Tests: `test/unit/theme_design_system_test.dart`, `test/widget/modern_ui_scale_test.dart`; goldens regenerated on Linux.
- **Acceptance evidence:**
  - AC1: ✅ test: [APP-08/AC1]
  - AC2: ✅ test: [APP-08/AC2]
  - AC3: ✅ test: [APP-08/AC3]
  - AC4: ✅ test: [APP-08/AC4]
  - AC5: ✅ test: [APP-08/AC5]
- **Decisions:** none
- **Follow-ups:** token cleanup of remaining screens (see below)

## Follow-ups
- Replace remaining literal paddings/sizes in `app_lock_gate.dart`, `paywall_screen.dart`, `profile_editor_screen.dart`, `profiles_screen.dart`, `vault_settings_screens.dart` with tokens.
