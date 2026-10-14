# Device verification — EXP-05 Vault Writer & Folder Routing Rules Engine

No physical device was available when this was authored, and the Kotlin (`SafHostApiImpl.readFile`)
and Swift (`BookmarkHostApiImpl.readFile`) additions were not compiled locally (no Android SDK /
Xcode on the authoring machine; the CI `android` job compiles Kotlin). The routing engine, the
exporter and the pipeline wiring are covered on the host by `[EXP-05/AC1]` / `[EXP-05/AC2]` tests
with fake and real-file writers.

Precondition for every row: a build whose pipeline engines factory passes
`vaultResolver: platformVaultWriterResolver(...)` (FND-11 wiring) and runs the pipeline isolate with
a `BackgroundIsolateBinaryMessenger` so Pigeon calls work there. Personal build (default) or a Pro
entitlement, so rules apply.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-05/AC2] | 1. In Obsidian create vaults `Personal` and `Work` on internal storage. 2. Settings › Vault folders › Add folder: pick `Personal`, then `Work`. 3. Settings › Routing rules › Add rule: folder `Work`, sub-folder `Meetings`, Profile ids `meeting`, Save. 4. Record a 20 s meeting-style note, stop, let processing finish. | Exactly one note appears in `Work/Meetings/` named `YYYY-MM-DD-meeting-<slug>.md`; nothing is written to `Personal`; Obsidian shows it without manual refresh. | arm64 Android phone + Obsidian | API 26+ | | | |
| [EXP-05/AC2] | Same as above on iOS, picking the two vault folders under "On My iPhone › Obsidian" (and once with an iCloud Drive vault). | Note lands only in `Work/Meetings/`; for iCloud the file syncs to a second device. | iPhone (iOS 16+) + Obsidian | iOS 16+ | | | |
| [EXP-05/AC2] | 1. Edit the rule: enable "Also check later rules"; add a second rule (no conditions) to `Personal`. 2. Record another note. | The note is written to both `Work/Meetings/` and the root of `Personal` (multi-match). | arm64 Android phone + Obsidian | API 26+ | | | |
| [EXP-05/AC2] | 1. Settings › Vault folders › `Work` › enable "Also save the transcript". 2. Re-run the last recording's export (re-render from the recording screen). | `<note>.transcript.md` appears next to the note; the note itself is updated in place (no `-2` copy). | iPhone (iOS 16+) + Obsidian | iOS 16+ | | | |
| [EXP-05/AC2] | 1. Edit the exported note in Obsidian. 2. Set `Work` › "If the note already exists" to Skip; re-render. 3. Set it to "Replace my earlier export"; re-render. | Step 2 leaves the edited note untouched; step 3 replaces it (user-edit detection via `readFile` works through SAF / bookmarks). | arm64 Android phone + Obsidian | API 26+ | | | |

## Notes / evidence
Screenshots under `docs/test-plans/device/evidence/EXP-05/`.
