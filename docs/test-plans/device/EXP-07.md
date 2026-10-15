# Device verification — EXP-07 Template Editor with Live Preview (Pro)

Host tests (`[EXP-07/AC1]`) prove the 150 ms debounce and a < 50 ms average render of the built-in
meeting template on the CI host; these rows confirm the budget and the editor on real phones.
No device was available when this was authored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-07/AC1] | 1. Settings › Templates › `meeting-default` › Duplicate → name `perf`. 2. In the editor type a few characters at the end of a line, stop typing and watch the Markdown preview (screen-record at 60 fps). | Preview text changes within 200 ms of the last keystroke (≤ 12 frames in the recording). No dropped input while typing. | low-end arm64 Android phone (4 GB RAM) | API 26+ | | | |
| [EXP-07/AC1] | 1. In the `perf` template delete a closing tag (e.g. `{{/data.has_action_items}}`). | The line number of the broken section shows `⚠`, the problem list shows "Line N, column M: …", tapping it moves the cursor there; Save is refused with "Fix 1 problem before saving." | iPhone (iOS 16+) | iOS 16+ | | | |
| [EXP-07/AC1] | 1. Toggle Rendered. 2. Add `![x](https://example.com/a.png)` to the template. | Rendered preview shows `[image: x]`; no network request (check with a proxy / Little Snitch / Android network inspector). | arm64 Android phone | API 26+ | | | |

## Notes / evidence
Screen recordings under `docs/test-plans/device/evidence/EXP-07/`.
