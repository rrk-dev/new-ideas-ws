# Device verification — EXP-08 Share Sheet & Alternate Outputs

Host tests (`[EXP-08/AC1]`) validate the Logseq page structure of every Logseq variant and the
share/copy flow with a fake share service; these rows confirm the real Logseq import and the OS
share sheet. No device was available when this was authored.

Setup: process one recording each with the Meeting, Warranty and Engineering profiles, no vault
folder configured. Open the recording (Library › recording › processing status) › Share.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-08/AC1] | 1. Format Logseq › "Share as .md file" › save to Files / a folder. 2. Copy the three files into `pages/` of a Logseq graph (Logseq desktop or mobile) and re-index. | Each page opens with its page properties (type, date link, tags) shown as properties, an outline of bullets, tasks as TODO; the date links point to journal pages. | Logseq desktop 0.10.x + any phone | macOS / Android / iOS | | | |
| [EXP-08/AC1] | Android: Format Obsidian › "Share as .md file" › pick Gmail draft / Files; then "Share as text" › Keep / Messages; then "Copy to clipboard" and paste into another app. | Chooser opens; the attached file is `<date>-<profile>-<slug>.md` and opens as Markdown; the text share contains the whole note; the clipboard holds the note. | arm64 Android phone | API 26+ | | | |
| [EXP-08/AC1] | iOS (and iPad, popover anchored on the share button): same three actions; "Save to Files" for the file. | Share sheet opens (iPad: anchored popover, no crash); file saved as `.md`; text and clipboard contain the note. | iPhone + iPad | iOS 16+ | | | |
| [EXP-08/AC1] | Format Plain › Share as text into a plain-text app (e.g. Notes). | No YAML front-matter, no `[[…]]` links. | any phone | any | | | |

## Notes / evidence
Screenshots under `docs/test-plans/device/evidence/EXP-08/`.
