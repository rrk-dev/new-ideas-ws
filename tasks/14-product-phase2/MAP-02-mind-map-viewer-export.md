# MAP-02 — Mind-map viewer and export

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** MAP-01, UIX-01, STT-06, EXP-05 | **Source:** User decision 2026-10-16 (product Phase 2: mind maps)
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-markdown-vault-export, vv-privacy-security, vv-testing

## Goal
Users can view a recording's mind map on phone and desktop, jump from a node to the transcript, and export the map into their vault.

## Scope
- [ ] Viewer in the recording detail (a tab or section per UIX-01): pan, zoom, collapse/expand, readable at large text sizes, Lumen design tokens, light and dark. Rendering is plain Flutter (`CustomPainter`/widgets); no new third-party package unless an ADR and dependency review approve it.
- [ ] Node tap shows the node's evidence and opens the transcript at its timestamp through the existing `TranscriptNavigator`.
- [ ] Empty, generating, failed and "not generated yet" states, with a Generate / Regenerate action that calls the MAP-01 on-demand path.
- [ ] Export as a nested Markdown list inside the note (new template section) and as a standalone `.md` file through the vault writer (EXP-05) with the usual filename rules. Optionally also a Mermaid `mindmap` code block: verify against the Mermaid version bundled in current Obsidian and Logseq before claiming support, and ship it only if it renders; the nested list is the guaranteed format.
- [ ] Share/export of an image (PNG) only if it can be done with existing platform share paths (EXP-08) without a new dependency; otherwise record as a follow-up.
- [ ] Accessibility: every node reachable by screen reader in tree order with a text alternative of the whole map; hit targets ≥ 44 pt (APP-06 rules).
- [ ] Markdown sanitisation of node labels (`vv-markdown-vault-export`): no front-matter or link injection from model output.

## Acceptance Criteria
- Widget tests cover empty, generating, failed and populated states, collapse/expand and node-to-transcript navigation (`[MAP-02/AC1]`).
- Exported nested list passes markdownlint and an adversarial-label test (labels with `]]`, `---`, backticks, HTML) renders inert (`[MAP-02/AC2]`).
- The note written to a vault with the mind map section matches the golden file for full and empty maps (`[MAP-02/AC3]`).
- `accessibility_test` checks pass in light and dark, and a screen-reader traversal test lists all nodes (`[MAP-02/AC4]`).
- A 40-node map pans and zooms at ≥ 55 fps on a Mid-tier device in profile mode (device row `docs/test-plans/device/MAP-02.md`, ⏳ until run).
- If Mermaid output is shipped, a device/desktop row records which Obsidian version rendered it; otherwise the Mermaid scope item is marked deferred with the reason.
