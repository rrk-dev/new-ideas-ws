# Device verification — EXP-09 macOS Vault Folder Bookmarks

The bookmark path has run against a fake host
(`app/test/unit/export/macos_bookmark_test.dart`). A real folder picker was
not run: the macOS runner is FND-09's (`app/macos` is not edited here) and
this session did not accept the Xcode license. Leave Result, Date, and
Tester blank until someone runs the steps. Do not mark PASS without that run.

Setup: merge `packages/vv_native/macos/MacBookmarkPanel.swift` and
`VaultFolder.entitlements` into the macOS runner (user-selected read-write
only; no downloads and no all-files). Then
`cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer fvm flutter run -d macos --flavor dev -t lib/main_dev.dart`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [EXP-09/AC2] | 1. Launch the dev macOS app. 2. In Settings, pick an Obsidian or Logseq folder with the system folder panel. 3. Quit the app and launch it again. Do not pick the folder a second time. 4. Export a note. 5. Open the same folder in Finder. | The note file is at the chosen folder, same relative path the app shows, and its bytes are the note Markdown. Moving the folder and launching again asks for a new pick rather than writing to the old path. | This Mac | macOS 13+ arm64 | | | |

## Notes / evidence
Automated counterparts: `[EXP-09/AC1]` resolves a stored bookmark after a simulated restart and checks the writer bytes; `[EXP-09/AC3]` checks every entitlements file under `packages/vv_native/macos`. FND-09 still has to compile `MacBookmarkPanel.swift` and merge `VaultFolder.entitlements`.
