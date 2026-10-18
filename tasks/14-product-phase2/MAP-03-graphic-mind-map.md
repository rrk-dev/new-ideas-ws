# MAP-03 — Graphical mind map view

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** MAP-02 | **Source:** Owner request 2026-10-18 (mind map is text-based; wants a graphic one)
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-testing, vv-privacy-security

## Goal
The Mind map tab shows the existing validated map as a graphic: cards joined by curved connectors, pannable and zoomable, with the text tree kept as the accessible alternative and a PNG export.

## Scope
- [x] Pure-Dart deterministic left-to-right layout of the existing tree (`MindMapNode`); collapsed subtrees are laid out as leaves; long labels wrap to two lines with an ellipsis. No model, DB, native or network change.
- [x] Graph widget: rounded cards (root, branches, nodes) with Lumen colour-scheme tokens (light and dark), curved connectors, `InteractiveViewer` pan and pinch-zoom, fit-to-screen button, layout computed once per collapse change (no per-frame relayout).
- [x] Tap a node: select it (full label and evidence panel) and expand/collapse its children; timestamp chip opens the transcript through `TranscriptNavigator`.
- [x] Graph / Tree toggle; Graph is the default, Tree is the default when a screen reader is active and stays the screen-reader path.
- [x] Semantics per node (label, level, expanded state, button); hit targets ≥ 44 dp.
- [x] PNG export of the whole graph (`RepaintBoundary.toImage`) shared through `ShareService.shareFile`; no network, nothing logged.
- [x] Empty and one-node maps render without error.
- [x] Device checklist `docs/test-plans/device/MAP-03.md`.

## Acceptance Criteria
- The layout is deterministic: the same tree yields identical positions, parents are centred on their children and no two cards overlap (`[MAP-03/AC1]`).
- A 120-node map lays out within a 100 ms budget, pumps, and panning or zooming does not run the layout again (`[MAP-03/AC2]`).
- Tapping a node collapses and expands its children in the graph and shows the full label and the timestamp chip opens the transcript at the right time (`[MAP-03/AC3]`).
- The Graph / Tree toggle switches views, Graph is the default, Tree is the default with a screen reader (`[MAP-03/AC4]`).
- PNG export produces non-empty PNG bytes and hands a `.png` file to the share service (`[MAP-03/AC5]`).
- Every node has a Semantics label with its level and expanded state, and the Tree view lists all nodes (`[MAP-03/AC6]`).
- Interacting with and exporting a map logs nothing with label text, and adversarial labels stay inert text (`[MAP-03/AC7]`).
- Pinch-zoom and pan feel smooth on a real iPhone (`[MAP-03/AC8]`, device row `docs/test-plans/device/MAP-03.md`, ⏳ until run).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/MAP-03-graphic-mind-map · **Date:** 2026-10-18
- **Summary:** Pure-Dart `MindMapLayout` (`domain/mind_map_layout.dart`, left-to-right, parents centred, collapsed nodes as leaves) and `MindMapGraph` (`presentation/mind_map_graph.dart`): Lumen colour-scheme cards, cubic connectors, `InteractiveViewer`, fit button, layout cached until the collapse set or text scale changes. The tab gets a Graph/Tree `SegmentedButton` (Graph default, Tree default with a screen reader) and "Share as image" (`RepaintBoundary.toImage` → `<tmp>/vv/mind-map.png` → `ShareService.shareFile`). No new dependency, no model/DB/native/network change.
- **Deferred:** Radial layout (left-to-right only). Zoomed-out cards fall below the 48 dp tap-target guideline by design; the Tree view is the guideline-compliant path (MAP-02/AC4 still covers it).
- **Acceptance evidence:**
  - AC1: ✅ test: [MAP-03/AC1]
  - AC2: ✅ test: [MAP-03/AC2]
  - AC3: ✅ test: [MAP-03/AC3]
  - AC4: ✅ test: [MAP-03/AC4]
  - AC5: ✅ test: [MAP-03/AC5]; device: docs/test-plans/device/MAP-03.md
  - AC6: ✅ test: [MAP-03/AC6]
  - AC7: ✅ test: [MAP-03/AC7]
  - AC8: ⏳ device: docs/test-plans/device/MAP-03.md
