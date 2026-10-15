# Device / lab verification — PRF-03

Rows need real models and devices that were unavailable when this was authored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [PRF-03/AC1] | Run `make eval PROFILE=meeting` with a 3B-class model on the device lab (PRF-10) over the 30 meeting cases. | Action-item recall ≥ 80 %, precision ≥ 80 %, owner accuracy ≥ 70 %. | Lab device | — | | | |
| [PRF-03/AC2] | Export a meeting note to an Obsidian vault; open it with the Tasks plugin enabled. | Front-matter parses; `- [ ]` tasks are listed by the Tasks plugin. | Phone + Obsidian | — | | | |
