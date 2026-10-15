# Device verification — APP-05 Extraction Result Review & Edit Before Export

Host tests: `app/test/unit/pipeline/review_before_export_test.dart` (`[APP-05/AC1]`: a
review-first profile parks the job in `waiting(review)`, the edited result is what the real EXP-01
renderer writes to the vault, a finished note is re-rendered/re-exported after edits, a
re-extraction needs a new review), `app/test/widget/review_screen_test.dart` (`[APP-05/AC1]`
form edits are exported; `[APP-05/AC1]` the source link of an item opens the transcript at its
`t` timestamp with that line highlighted, and hands the position to `TranscriptNavigator`),
`app/test/unit/review/review_policy_test.dart`. The audio jump needs the STT-06 player
(`transcriptNavigatorProvider` override — see APP-02 follow-ups) and a real vault folder, which
could not be run when this was authored (no devices, STT-06 not merged).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [APP-05/AC1] Edits reach the vault note (Android) | 1. Settings › Review before export: switch *Meeting Action Items* to "Review first". 2. Record a 1–2 min meeting with two people naming a task and an owner. 3. Wait for "The result is waiting for your review" on the recording. 4. Review: correct an attendee's name, change the task's owner, add a decision; check Preview; tap "Export note". 5. Open the note in the vault (Obsidian / Files). | 3: nothing is written to the vault before step 4. 5: the note contains exactly the edited attendees, owner and decision (front-matter and body); no original misspelling remains. | arm64 Android | API 26+ | | | |
| [APP-05/AC1] Edits reach the vault note (iOS) | Same steps with an iOS bookmark vault folder. | Same as Android. | iPhone | iOS 16+ | | | |
| [APP-05/AC1] Source link seeks the audio | Build with STT-06 merged (its `TranscriptNavigator` override). 1. Open a reviewed meeting whose action item has a `t` timestamp (e.g. `00:00:12`). 2. Tap the ▶ link next to "Said at". | The transcript opens with the line at 0:12 highlighted and audio playback starts at 0:12 (± 0.5 s): you hear the sentence the task was taken from. | iPhone + arm64 Android | iOS 16+ / API 26+ | | | |

## Notes / evidence
Screenshots of the review form, preview and the resulting note under
`docs/test-plans/device/evidence/APP-05/`.
