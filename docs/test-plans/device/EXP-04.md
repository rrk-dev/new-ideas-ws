# Device verification — EXP-04 iOS Folder Access (Security-Scoped Bookmarks)

Rows need a physical iPhone (iOS 16+) with Obsidian installed, signed in to iCloud; none was
available when this was authored. The Swift host API (`BookmarkHostApiImpl.swift`) was
type-checked locally against the Mac Catalyst UIKit SDK with a stub Flutter module (no Xcode,
no iOS SDK) — it has never been built for iOS or run; the CI `ios` job builds it.

Common setup: `cd app && fvm flutter pub get`; select a signing team for the dev scheme.
"Pick phase" = `fvm flutter test integration_test/vault_folder_bookmark_test.dart --flavor dev -d <id> --dart-define=VV_BOOKMARK_PHASE=pick`
(copy the printed `VV_BOOKMARK=…` value);
"verify phase" = same with `--dart-define=VV_BOOKMARK_PHASE=verify --dart-define=VV_BOOKMARK=<value>`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-04/AC1] | 1. In Obsidian create a local vault `VV-Local` (On My iPhone › Obsidian › VV-Local). 2. Pick phase; choose `VV-Local` → Open. 3. Force-quit the app (app switcher). 4. Verify phase with the printed bookmark. | Both pass; verify shows no picker and writes `VaultVoice/EXP-04 after restart.md`. | iPhone | iOS 16+ | | | |
| [EXP-04/AC1] | 1. Reboot the iPhone, unlock. 2. Verify phase with the same bookmark. | Passes without a picker. | iPhone | iOS 16+ | | | |
| [EXP-04/AC1] | App update: 1. Bump `version:` build number in `app/pubspec.yaml` locally (do not commit). 2. `fvm flutter install --flavor dev -d <id>` over the existing install (no uninstall). 3. Verify phase with the same bookmark. | Passes; if a `VV_BOOKMARK (refreshed)=` line is printed, a stale bookmark was re-created and the next verify with the refreshed value also passes. | iPhone | iOS 16+ | | | |
| [EXP-04/AC1] | Revocation: 1. Delete or move `VV-Local` in Files. 2. Verify phase. | Fails with `revoked` (or `unavailable` for a moved folder that still resolves elsewhere) — nothing written to another place. Pick phase again → passes. | iPhone | iOS 16+ | | | |
| [EXP-04/AC2] | Local vault: 1. Open Obsidian on `VV-Local` and leave it in the background. 2. Pick phase choosing `VV-Local`. 3. Switch to Obsidian without reopening the vault. | `VaultVoice/EXP-04 check.md` appears in the file explorer, opens, front-matter `source: vaultvoice` and current timestamp shown. | iPhone + Obsidian iOS | iOS 16+ | | | |
| [EXP-04/AC2] | iCloud vault: 1. In Obsidian create a vault stored in iCloud (`iCloud Drive › Obsidian › VV-Cloud`). 2. Leave Obsidian open in background. 3. Pick phase choosing `VV-Cloud`. 4. Switch to Obsidian. | Note appears without manual refresh; on a second device/Mac with the same iCloud account the note syncs; no conflict copies. | iPhone + Obsidian iOS + iCloud | iOS 16+ | | | |
| [EXP-04/AC2] | iCloud placeholder: 1. On another device edit `VaultVoice/EXP-04 check.md` in `VV-Cloud`. 2. On the iPhone, in Settings › iCloud enable "Optimize iPhone Storage" or long-press the file in Files › "Remove Download". 3. Pick phase again (overwrite). | First attempt fails with `unavailable` (download started), file shows downloading in Files; re-running after download succeeds; exactly one `EXP-04 check.md`, no `EXP-04 check 2.md`. | iPhone + iCloud | iOS 16+ | | | |
| [EXP-04/AC1] | Default target: open Files › On My iPhone. | A `VaultVoice Dev` folder (app Documents) is listed (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`). | iPhone | iOS 16+ | | | |

## Notes / evidence
Screenshots/recordings under `docs/test-plans/device/evidence/EXP-04/`.
Local type-check command (macOS without Xcode): see the EXP-04 Completion Notes.
