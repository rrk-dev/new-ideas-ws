# Device / lab verification — MAP-03

Rows need a physical device that was unavailable when this was authored. Frame timing protocol: `docs/perf.md` (QA-03), profile mode.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [MAP-03/AC8] | Open the Mind map tab (Graph) on a recording with a 40-node map. Pan and pinch-zoom continuously for 20 s. | Feels smooth, ≥ 55 fps average, no frame over 32 ms; cards stay sharp and the connectors follow. | iPhone (mid-tier) + mid-tier Android | — | ⏳ | | |
| [MAP-03/AC8] | Tap the root and branch cards 10 times and press Fit to screen. | Collapse/expand is instant, no dropped-frame burst, Fit shows the whole map. | iPhone + Android | — | ⏳ | | |
| [MAP-03/AC5] | Press Share as image and send it to Photos / Files. | The PNG shows the whole map (not only the visible part) with a solid background in light and dark. | iPhone + Android | — | ⏳ | | |
| [MAP-03/AC6] | Turn on VoiceOver / TalkBack and open the Mind map tab. | The Tree view opens by default and every node is announced once with its level. | iPhone + Android | — | ⏳ | | |
