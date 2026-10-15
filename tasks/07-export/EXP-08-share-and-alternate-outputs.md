# EXP-08 — Share Sheet & Alternate Outputs

**Workstream:** Export | **Phase:** 3–4 | **Size:** S | **Depends on:** EXP-01 | **Source:** Gap (Logseq support mentioned in §1; users without a vault)
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
Get notes out even without a configured vault, and support non-Obsidian formats mentioned in the vision.

## Scope
- [x] Share rendered note via OS share sheet (text or `.md` file).
- [x] Copy to clipboard.
- [x] Logseq-flavoured template variant (outline bullets, `key:: value` properties).
- [x] Plain-text / no-front-matter variant.

## Acceptance Criteria
- Logseq variant imports correctly into a Logseq graph folder; share works on both platforms.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-08-share-alternate-outputs · **Date:** 2026-10-14
- **Summary:** New built-in variants `warranty-logseq`, `warranty-plain`, `engineering-logseq`,
  `engineering-plain` (every built-in profile now has Obsidian / Logseq / plain;
  `builtinVariant(profile, flavor)`), with Markdown goldens (full / empty / adversarial,
  markdownlint-clean). `NoteSharing` (`export/data/note_sharing.dart`) renders a processed
  recording in the chosen format (Obsidian = the exported vault note; Logseq / plain = the
  profile's variant; custom profiles: plain = vault note without front-matter, no Logseq) and
  writes the share file to a fresh temp folder. `ShareNoteButton` / `ShareNoteSheet`
  (`export/presentation/share_note_sheet.dart`, on the recording status screen's app bar) offers
  "Share as .md file" (`text/markdown`), "Share as text" (new `ShareService.shareText`, share_plus
  13.3.1 `ShareParams.text`) and "Copy to clipboard"; works without any vault folder.
- **Acceptance evidence:**
  - AC1: ⏳ test: [EXP-08/AC1]; device: docs/test-plans/device/EXP-08.md
- **Decisions:** none beyond the conservative defaults above (Obsidian format preselected).
- **Follow-ups:** none.

