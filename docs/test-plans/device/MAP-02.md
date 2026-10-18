# Device / lab verification — MAP-02

Rows need physical devices that were unavailable when this was authored. Protocol for frame timing: `docs/perf.md` (QA-03), profile mode, the DevTools performance overlay or `flutter drive --profile` timeline summary.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [MAP-02/AC5] | Open the Mind map tab of a recording whose map has 40 nodes (3 levels). Pan and pinch-zoom continuously for 20 s in a profile build. | ≥ 55 fps average, no frame over 32 ms (summary from the timeline). | Mid-tier Android + iPhone | — | ⏳ | | |
| [MAP-02/AC5] | Same map, collapse and expand the root 10 times. | No dropped-frame burst; layout stays under 16 ms per frame. | Mid-tier Android + iPhone | — | ⏳ | | |
| [MAP-02/AC4] | Turn on TalkBack / VoiceOver, swipe through the Mind map tab. | Every node is announced once, in tree order, with its level; the whole-map summary is read first. | Any Android + iPhone | — | ⏳ | | |
| [MAP-02/AC3] | Enable "Also write the mind map" on a vault folder, export a recording with a map. | The note ends with a "Mind map" section and a `<note>.mindmap.md` file sits beside it; Obsidian and Logseq show the list without links or front-matter. | Android (SAF folder) + iPhone (bookmark folder) | — | ⏳ | | |
