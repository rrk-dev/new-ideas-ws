# Device verification — ASK-04 Ask-your-notes UI

Host evidence: `app/test/widget/ask_ui_test.dart` (`[ASK-04/AC1]`, `[ASK-04/AC2]`),
`app/test/widget/accessibility_test.dart` (`[ASK-04/AC3]`, Ask and Ask history in light and dark)
and `app/test/unit/l10n/hardcoded_strings_test.dart`.

Prerequisites: a High-tier phone (7 GiB RAM or more), the 3B model installed from Settings → Models,
a seeded library of at least five processed recordings, and **Settings → Processing → Ask your
notes** switched on (the Ask entry is hidden while `ask.enabled` is off, the shipped default).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [ASK-04/AC4] | 1. Library → Ask. 2. Ask a question one recording answers. 3. Tap a source chip. 4. Ask something the notes never mention. 5. Open the recording's Ask tab and ask about only that recording. | A cited answer within a reasonable time, the "answers can be wrong" note under it, the chip opens the transcript at that time, the unrelated question gets "I couldn't find that in your notes.", the per-recording chat only cites that recording. | High-tier iPhone | iOS 16+ | ⏳ | | |
| [ASK-04/AC4] | Same steps. | Same. | High-tier arm64 Android phone | API 26+ | ⏳ | | |
| [ASK-04/AC5] | Switch on airplane mode, force-quit and relaunch Lumen, ask a question (steps 1-3 above). | Ask works with the network off; the Network activity log shows no new request. | High-tier phone | iOS 16+ / API 26+ | ⏳ | | |
| [ASK-04/AC4] | Mid or Low tier phone: switch Ask on in settings, open Library → Ask. | "Ask isn't available on this device." No download offered. | Mid/Low phone | any | ⏳ | | |
| [ASK-04/AC4] | High-tier phone without the 3B: open Ask. | "Ask requires the 3B model" with the download size and a download button. | High-tier phone | any | ⏳ | | |
| [ASK-04/AC4] | Ask a question, lock the app (App lock on, background it past the timeout), unlock. Then Settings → Privacy → Ask history: open a chat, delete one, clear all. | The conversation is gone after the lock; history lists chats, delete-one and clear-all remove them. | High-tier phone | any | ⏳ | | |

## Notes / evidence
Screenshots under `docs/test-plans/device/evidence/ASK-04/`.
