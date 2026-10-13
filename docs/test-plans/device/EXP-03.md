# Device verification — EXP-03 Android Folder Access (Storage Access Framework)

Rows need a physical Android phone (API 26+, arm64) with Obsidian installed; none was available
when this was authored. The Kotlin host API (`SafHostApiImpl.kt`) has never been compiled locally
(no Android SDK) — the CI `android` job compiles it. Unit tests with a fake host cover the Dart side.

Common setup: `cd app && fvm flutter pub get`. Device id from `fvm flutter devices`.
"Pick phase" = `fvm flutter test integration_test/vault_folder_saf_test.dart --flavor dev -d <id> --dart-define=VV_SAF_PHASE=pick`;
"verify phase" = same with `--dart-define=VV_SAF_PHASE=verify`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-03/AC1] | 1. In Obsidian create vault `VV-Test` on internal storage (`Documents/VV-Test`). 2. Run the pick phase; in the system picker open `Documents/VV-Test` → "Use this folder" → Allow. 3. Force-stop the app (Settings › Apps › VaultVoice Dev › Force stop). 4. Run the verify phase. | Pick phase passes. Verify phase passes without any picker appearing; `VaultVoice/EXP-03 after restart.md` exists in the vault. | arm64 Android phone | API 26+ | | | |
| [EXP-03/AC1] | 1. After the row above, reboot the phone and unlock it. 2. Run the verify phase again. | Passes without a picker; the note's timestamp updates (overwrite, no " (1)" duplicate). | arm64 Android phone | API 26+ | | | |
| [EXP-03/AC1] | 1. Settings › Apps › VaultVoice Dev › Storage/Permissions: clear the folder access (or Settings › Apps › Special access, depending on OEM), or delete the `VV-Test` folder in a file manager. 2. Run the verify phase. | Verify phase **fails** with `VaultAccess.revoked` (or no persisted tree) — revocation is detected, nothing is written elsewhere. Re-run the pick phase (picker opens) → passes again. | arm64 Android phone | API 26+ | | | |
| [EXP-03/AC1] | (SD card / removable storage, if the device has a slot) 1. Create an Obsidian vault on the SD card. 2. Pick phase → choose it. 3. Unmount/remove the SD card. 4. Verify phase. 5. Re-insert, verify phase. | Step 4 fails with `unavailable` (not `revoked`); step 5 passes without a picker. | Android phone with SD slot | API 26+ | | | |
| [EXP-03/AC2] | 1. Open Obsidian on vault `VV-Test` and leave it open in the background. 2. Run the pick phase (choose the vault folder). 3. Switch to Obsidian without pulling to refresh or reopening the vault. | `VaultVoice/EXP-03 check.md` appears in the file explorer within ~2 s, opens, shows the front-matter property `source: vaultvoice` and the current timestamp. | arm64 Android phone + Obsidian Android | API 26+ | | | |
| [EXP-03/AC2] | 1. Run the pick phase again with the same folder (overwrite). 2. Look at the note in Obsidian. | Content updates in place (new timestamp, no stale trailing bytes, no `EXP-03 check (1).md`, no `.vvtmp` file visible). | arm64 Android phone + Obsidian Android | API 26+ | | | |
| [EXP-03/AC2] | Scope check — Syncthing/FolderSync: 1. Point a Syncthing (or FolderSync) folder at a vault folder. 2. Pick phase on that folder. | Note is written and picked up by the sync app's next scan; no permission error. | arm64 Android phone + Syncthing-Fork or FolderSync | API 26+ | | | |

## Notes / evidence
- Grants: `adb shell dumpsys activity permissions | grep -A2 vaultvoice` lists the persisted tree URI
  (expected after the pick phase, still present after reboot).
- Screenshots/recordings under `docs/test-plans/device/evidence/EXP-03/`.
