# UIX-01 — Reference-driven UI refresh (Pocket-style structure on the Lumen design system)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** APP-08, APP-09, APP-02, APP-05 | **Source:** User decision 2026-10-16 (product Phase 2: enhance the UI by observing the heypocket mobile app)
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing, vv-decision-records

## Goal
Reshape the Library and Recording detail screens so the new features (summary, transcript, mind map, ask, action items) are easy to reach, using patterns observed in the reference app while keeping Lumen's own identity.

## Scope
- [x] **Input needed from the user before design starts (satisfied: 7 screenshots supplied 2026-10-17):** screenshots or a screen recording of the reference app's mobile screens (home/library, a recording detail, a summary view, any mind-map and ask views). The reference app's interface was **not** inspected by the agents (only its public marketing page and a search summary were read), so no layout detail may be assumed. If nothing is supplied this task stays blocked.
- [x] From the supplied material write `docs/design/reference-ui-study.md`: what each screen contains, navigation structure, information hierarchy, what we adopt, what we deliberately do not. Adopt patterns (e.g. grouping, tabs, card density), never the reference app's branding, icons, copy, colours or assets.
- [x] Mockups or a described layout for: Library list (grouping, filters, search entry, empty state), Recording detail as a sectioned/tabbed hub with slots for Summary, Transcript, Action items, Mind map (MAP-02) and Ask (ASK-04), and the Record screen entry from quick capture (QCP-02/QCP-03). Light and dark; phone and macOS window widths.
- [x] Implement the restructure using existing Lumen tokens and shared widgets (`app_tokens.dart`, `LumenCard`, `SectionHeader`, …); unbuilt features appear only as hidden slots (no dead placeholders in production UI).
- [x] Keep every existing route, deep link, provider and feature working; no behaviour change besides navigation structure.
- [x] Regenerate the affected goldens only on Linux through `tools/ci/update_goldens.sh`.

## Acceptance Criteria
- `docs/design/reference-ui-study.md` exists, is based only on user-supplied material (listed in the file) and has an explicit "not copied" list (artifact).
- The Library and Recording detail screens implement the agreed structure; existing library, search, action items, review and transcript tests still pass (`flutter test` targeted files listed in Completion Notes).
- `accessibility_test` (contrast, tap targets, text scale 1.0–2.0) and `modern_ui_scale_test` pass for the changed screens in light and dark; goldens regenerated and reviewed (`[UIX-01/AC3]`).
- No hard-coded user-visible strings (`hardcoded_strings_test`) and no new package or network host (`check_egress.sh`).
- A human compares the result with the reference material and signs the design review row in `docs/test-plans/device/UIX-01.md` (⏳ until done).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/UIX-01-reference-ui · **Date:** 2026-10-17
- **Summary:** `docs/design/reference-ui-study.md` (AC1, with supplied-material and "not copied"
  lists and layout notes). Library: date sections (Today/Yesterday/Earlier this week/Earlier, only
  for Newest/Oldest sort) in `GroupedCard`s, round app-bar buttons. Recording detail: tabbed hub
  (Summary, Transcript, Action items) plus `recordingHubSlotsProvider` for Mind map/Ask (empty →
  no tab). New shared widgets `GroupedCard`, `CircleIconButton`. Routes, providers and deep links
  unchanged. Existing detail test adapted to switch tabs.
- **Tests:** `[UIX-01/AC2]` in `library_screen_test.dart`; `[UIX-01/AC3]` Recording detail added to
  `modern_ui_scale_test.dart` (light/dark, 2.0×); `accessibility_test` covers Library and detail;
  goldens regenerated through `tools/ci/update_goldens.sh` (library + recording detail).
- **Acceptance evidence:**
  - AC1: ✅ artifact: docs/design/reference-ui-study.md
  - AC2: ✅ test: [UIX-01/AC2]
  - AC3: ✅ test: [UIX-01/AC3]
  - AC4: ✅ ci: hardcoded_strings_test and tools/ci/check_egress.sh pass, no package or host added
  - AC5: ⏳ device: docs/test-plans/device/UIX-01.md
- **Privacy checklist:** no network, no logging, no new packages.
- **Unverified:** AC5 human design review (⏳ `docs/test-plans/device/UIX-01.md`); macOS-width
  render checked by layout constraint only (no wide golden).

## Follow-ups
- Record screen live bar (waveform + timer + Finish styling) not restyled (risk vs. policy tests).
- Radio-row picker and chat layout apply to the template picker / Ask tasks.
- Wide-width (macOS) goldens need a golden helper with a second surface size.
