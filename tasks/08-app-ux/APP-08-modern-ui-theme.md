# APP-08 — Modern UI: design system and screen restyle

**Workstream:** App UX | **Phase:** 4 | **Size:** L | **Depends on:** APP-07 | **Source:** User request 2026-10-16
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing

## Goal
A calm, minimal, modern look (soft neutrals, one teal accent, generous spacing) applied through one design system so every screen inherits it.

## Scope
- [ ] Design tokens in `lib/core/theme`: colour scheme (light and dark), type scale, spacing, radii, elevation, motion; no hard-coded colours or sizes in features.
- [ ] Themed components: buttons, cards, list tiles, inputs, chips, app/nav bars, dialogs, bottom sheets, progress, empty and error states.
- [ ] Restyle onboarding, Record (large primary record control, live level meter), Library, note detail, Process/Models, Settings.
- [ ] Respect system light/dark, text scaling to 200%, reduced motion, and 48 dp touch targets.
- [ ] Goldens regenerated on Linux for changed screens.

## Acceptance Criteria
- Light and dark themes are defined once in `lib/core/theme`; a test fails if a feature file uses a raw `Color(0x…)` literal outside the theme.
- Text and control contrast meets WCAG AA (4.5:1 body, 3:1 large) in both themes, verified by a test over the colour tokens.
- All primary screens render without overflow at text scale 2.0 (widget tests).
- Screen goldens for onboarding, Record, Library, Settings and Models exist in light and dark.
- No behaviour change: existing tests pass.
