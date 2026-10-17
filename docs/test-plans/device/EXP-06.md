# Device verification — EXP-06 Write Failure Handling & Export Outbox

`[EXP-06/AC1]` host tests drive the real pipeline orchestrator, `VaultExporter` and outbox with
fake folder writers (revoke → waiting(destination) → re-grant → exactly one note; re-grant to a
different folder; app-local fallback; disk full → backoff retry). These rows repeat the
criterion with real OS grants. Needs the FND-11 wiring (`vaultResolver` in the engines factory).
No device was available when this was authored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-06/AC1] | 1. Settings › Vault folders: add an Obsidian vault folder. 2. Android Settings › Apps › Lumen › revoke folder access (or delete/rename the folder in Files). 3. Record a 20 s note and let it process. 4. Settings › Pending exports: the note shows "Access to <folder> was removed". 5. Tap "Re-grant access", pick the same folder. | After step 3 the job shows "waiting"; no file is written anywhere. After step 5 exactly **one** note appears in the vault (no `-2` copy, no `.vvtmp`), the pending list is empty. | arm64 Android phone + Obsidian | API 26+ | | | |
| [EXP-06/AC1] | iOS: pick an iCloud Drive Obsidian vault; turn on Airplane mode with the note's file evicted (or move the vault folder in Files to break the bookmark); process a recording; then restore (Airplane off / re-grant via "Re-grant access"). | While unavailable: "not reachable … retrying" (iCloud) or "Access … removed" (moved); afterwards exactly one note in the vault, also visible on a second device. | iPhone + iCloud Drive | iOS 16+ | | | |
| [EXP-06/AC1] | SD card: vault on removable storage; eject the card; process a recording; re-insert, bring the app to the foreground. | Note pending as "not reachable"; after resume the outbox rechecks and writes exactly one note. | Android phone with SD slot | API 26+ | | | |
| [EXP-06/AC1] | Disk full: fill the device (or the SD card) to < 1 MB free; process a recording; free space; wait for the retry or tap "Retry now". | No crash, note pending meanwhile, then exactly one note. | any Android phone | API 26+ | | | |

## Notes / evidence
Screenshots under `docs/test-plans/device/evidence/EXP-06/`.
