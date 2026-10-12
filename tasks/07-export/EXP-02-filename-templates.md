# EXP-02 — Filename Templates, Sanitization & Collisions

**Workstream:** Export | **Phase:** 3 | **Size:** S | **Depends on:** EXP-01 | **Source:** §3.1.4 (`YYYY-MM-DD-Meeting-Topic.md`)
**Status:** todo
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-testing

## Goal
Predictable, valid, configurable filenames and sub-folder paths.

## Scope
- [ ] Pattern tokens: `{{date:YYYY-MM-DD}}`, `{{time}}`, `{{profile}}`, `{{title}}`, `{{slug}}`, sub-folders (`{{date:YYYY}}/{{date:MM}}/`).
- [ ] Sanitize for iOS/Android/Windows-synced vaults (reserved chars, length ≤ 255 bytes, trailing dots/spaces, emoji handling).
- [ ] Collision strategy: append `-2`, overwrite (re-export of same recording), or skip — configurable.
- [ ] Stable identity: store export path per recording to update instead of duplicate on re-export.

## Acceptance Criteria
- Unit tests for sanitization edge cases and all collision modes.
