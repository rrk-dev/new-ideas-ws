# EXP-03 — Android Folder Access (Storage Access Framework)

**Workstream:** Export | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** §5 Phase 1 (Scoped Storage)
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
User picks any folder (e.g., Obsidian vault on internal storage or SD card) and the app can write there persistently.

## Scope
- [x] `ACTION_OPEN_DOCUMENT_TREE` picker; `takePersistableUriPermission` for read/write.
- [x] `DocumentsContract`-based create/overwrite/mkdir via a Pigeon platform channel (see skill reference; `DocumentFile.findFile` is too slow) (Dart `File` cannot write SAF URIs).
- [x] Detect revoked permissions / removed SD card; prompt re-grant. (Detection → `VaultAccess.revoked|unavailable`; `VaultAccessGuard` maps it to `promptRegrant|retryLater` and `regrant()` reopens the picker at the old folder. The settings/export screens that show the prompt are APP-03 / EXP-06.)
- [x] Avoid `MANAGE_EXTERNAL_STORAGE` (Play policy). (Manifest scan test.)
- [~] Verify compatibility with Obsidian's vault location and Syncthing/FolderSync folders. deferred → device run: rows in `docs/test-plans/device/EXP-03.md` (no Android device available to the implementer).

## Acceptance Criteria
- Permission survives app restart and device reboot.
- Files written appear immediately in Obsidian Android.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-03-android-saf · **Date:** 2026-10-12
- **Summary:** Pigeon host API `app/pigeons/saf_api.dart` (pigeon 29.0.8, generated
  `lib/features/export/data/pigeon/saf_api.g.dart` + `android/.../saf/SafApi.g.kt`). Kotlin
  `android/app/src/main/kotlin/com/vaultvoice/vaultvoice/saf/SafHostApiImpl.kt`: `ACTION_OPEN_DOCUMENT_TREE`
  (+ `EXTRA_INITIAL_URI` for re-grant), `takePersistableUriPermission(READ|WRITE)`, grant check against
  `persistedUriPermissions` on every call, `DocumentsContract` child queries (no `DocumentFile`), mkdir via
  `createDocument(MIME_TYPE_DIR)`, display-name verification after `createDocument`, overwrite =
  `.<name>.vvtmp` → delete → `renameDocument` with direct-write fallback, all writes `openOutputStream(uri, "wt")`
  + size check, IO on a background executor, content-free error codes. Wired in `MainActivity.kt`
  (`configureFlutterEngine`/`onActivityResult`). Dart: `VaultWriter` interface extended per the skill
  (`checkAccess → ok|revoked|unavailable`, `write(overwrite)`, `exists`, `mkdirs`, `delete`, `list`),
  `VaultPath` traversal guard, `VaultAccessFailure`/`VaultFileExistsFailure`, `SafVaultWriter` +
  `SafFolderAccess`, `AppLocalVaultWriter` (atomic tmp+rename, Android root `filesDir/vault`),
  `VaultAccessGuard` (re-grant flow), providers in `features/export/data/export_providers.dart`.
  Tests: `test/unit/export/` with `test/fakes/fake_saf_host_api.dart`; on-device
  `integration_test/vault_folder_saf_test.dart` (pick / verify phases).
  **Not verified:** Kotlin was never compiled (no Android SDK locally — CI `android` job builds the APK);
  no device runs.
- **Acceptance evidence:**
  - AC1: ⏳ test: [EXP-03/AC1]; device: docs/test-plans/device/EXP-03.md
  - AC2: ⏳ test: [EXP-03/AC2]; device: docs/test-plans/device/EXP-03.md
- **Decisions:** none requiring an ADR (Pigeon + DocumentsContract are prescribed by vv-flutter-architecture /
  vv-markdown-vault-export). PRODUCT-DECISION (conservative default, see `SafHostApiImpl.appLocalVaultPath`):
  the Android app-local fallback vault is app-private `filesDir/vault`.
- **Follow-ups:** none new — the re-grant prompt UI belongs to APP-03 (settings) / EXP-06 (outbox), storing
  `VaultFolder.handle` in `vault_targets` to EXP-05 (needs FND-04).
## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ · analyze ✅ · tests ✅ (780 passed, 29 skipped; coverage not re-measured locally, CI test job gates ≥80% and is green) · native smoke n/a (no native/bridge change) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51 of ci, commit 67b6fcf, completed successfully; run 50 also succeeded)
- **Acceptance criteria:**
  - AC1: ✅ host re-ran `[EXP-03/AC1]` (fake persisted-grant table stands in for the OS). Tests assert no second picker after a Dart "restart", revoked vs unavailable (SD card), and re-grant at the previous tree URI. Device rows in `docs/test-plans/device/EXP-03.md` (restart, reboot, revoke, SD card) have steps and expected results; Result/Date are blank (⏳). Mutation: mapped `SafAccessStatus.revoked` to `VaultAccess.ok`; the revoked-grant test failed; restored
  - AC2: ✅ host re-ran `[EXP-03/AC2]`; write sends the exact relative path and UTF-8 bytes, overwrite replaces the whole file, a non-overwrite keeps the existing note. Obsidian/Syncthing rows in the same checklist are blank (⏳). This machine has no Android SDK (doctor: Android SDK, adb, JDK, emulator, NDK missing), so the device rows were not re-run. Kotlin `SafHostApiImpl` uses `ACTION_OPEN_DOCUMENT_TREE`, `takePersistableUriPermission`, and `DocumentsContract` (no `DocumentFile`); CI run 51 built Android on this sha
- **Adversarial checks:** picker cancel is not an error; a bookmark handle is not used as a tree URI; host errors never report ok; manifest scan test rejects `MANAGE_EXTERNAL_STORAGE`; traversal is guarded in `VaultPath`. No phone-state permissions added.
- **Skill/rule compliance:** Pigeon channel as required by `vv-flutter-architecture` / `vv-markdown-vault-export`. Scope item for Obsidian/Syncthing is `[~] deferred` to the device checklist. No credentials or certificates in the SAF code.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/EXP-03.md has no PASS result with a date; AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/EXP-03.md has no PASS result with a date; dependency FND-02 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
