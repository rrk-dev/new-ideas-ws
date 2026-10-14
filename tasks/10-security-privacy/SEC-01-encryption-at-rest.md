# SEC-01 — Encryption at Rest

**Workstream:** Security & Privacy | **Phase:** 2–3 | **Size:** M | **Depends on:** FND-04, AUD-01 | **Source:** Gap (HIPAA/legal positioning in §2.1, §6.1 requires it)
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-local-database, vv-decision-records, vv-audio-capture, vv-ffi-bridge, vv-testing

## Goal
Audio, transcripts and the database are encrypted on device, beyond default OS protection.

## Scope
- [x] Encrypted SQLite for the drift database (sqlite3 v3 build hooks: `sqlite3mc` recommended or `sqlcipher` — decide in ADR); key in iOS Keychain / Android Keystore (hardware-backed where available).
- [x] iOS Data Protection class `completeUntilFirstUserAuthentication` for files (`complete` blocks background recording — document trade-off).
- [x] **Phase-1 design step (before AUD-01 finishes):** ADR `ADR-SEC-01-file-encryption` deciding OS file encryption only (iOS Data Protection + Android credential-encrypted storage) vs app-level `vvenc` framed AES-256-GCM format (spec in `vv-audio-capture` → Chunk writer).
- [~] deferred → SEC-10 (ADR-SEC-01 chose OS file encryption for v1, so no `vvenc` codec now). If `vvenc`: iOS **and** Android encrypt audio chunks, rendered Markdown and work files with a per-file key wrapped by the Keychain/Keystore master key (custom AES-GCM; Jetpack Security is deprecated); native reader decrypts in the bridge (`vv_key`), playback via decrypting `StreamAudioSource`.
- [x] Exclude app data from cloud backups by default; opt-in encrypted backup/export (stretch → SEC-11).
- [x] Note: exported vault Markdown is intentionally plaintext (user-controlled); state clearly in UI.

## Acceptance Criteria
- Pulling app container files from a debug/rooted device shows no plaintext transcripts or audio.
- Background recording still works with chosen protection class.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/SEC-01-encryption-at-rest · **Date:** 2026-10-14
- **Summary:** sqlite3mc build (`app/pubspec.yaml` hooks user_defines) + `Sqlite3mcCipher`
  (`app/lib/core/security/sqlite3mc_cipher.dart`: asserts `PRAGMA cipher`, `PRAGMA hexkey`,
  in-place `hexrekey` of a pre-SEC-01 plaintext DB, fail-closed `UnavailableCipher`);
  `KeyVault` + `StorageProtection` over channel `vaultvoice/secure_storage`
  (`app/lib/core/security/key_vault.dart`, `storage_protection.dart`; native
  `app/ios/Runner/SecureStoragePlugin.swift` — Keychain `AfterFirstUnlockThisDeviceOnly`, Data
  Protection `completeUntilFirstUserAuthentication` + `isExcludedFromBackup` on `vv/`;
  `app/android/.../security/SecureStoragePlugin.kt` — AndroidKeyStore AES-GCM-wrapped key in
  `noBackupFilesDir`, StrongBox when present, no user-auth requirement);
  `prepareEncryptionAtRest()` wired in `bootstrap.dart` (iOS/Android); Settings → Encryption
  shows On / Unavailable / Off from `encryptionStatusProvider` and states that vault exports are
  plaintext. Android backup exclusion (allowBackup=false + dataExtractionRules +
  fullBackupContent) was already in place from FND-04 and is re-asserted by the FND-04 test.
  The Swift plugin was type-checked with `swiftc -typecheck` against a Flutter stub; Kotlin and
  the Xcode project change are compiled by the CI `android` / `ios` jobs (no SDKs locally).
- **Acceptance evidence:**
  - AC1: ⏳ test: [SEC-01/AC1]; device: docs/test-plans/device/SEC-01.md; artifact: docs/adr/ADR-SEC-01-file-encryption.md
  - AC2: ⏳ test: [SEC-01/AC2]; device: docs/test-plans/device/SEC-01.md
- **Decisions:** ADR-SEC-01-file-encryption (Proposed). PRODUCT-DECISION: audio chunks and
  `rendered/*.md` rely on OS file encryption (readable by root on an unlocked device); if the
  strict AC reading is required for audio, do SEC-10.
- **Follow-ups:** SEC-10, SEC-11 (proposed below)

## Follow-ups
- SEC-10 (proposed): app-level `vvenc` for audio chunks + `rendered/*.md` behind
  `AudioChunkCodec` (native decrypting reader with `vv_key` in the bridge, decrypting
  `StreamAudioSource` for playback, crypto-shredding) — only if the user wants protection against
  root on an unlocked device (ADR-SEC-01 → "What the acceptance criteria mean").
- SEC-11 (proposed, stretch): opt-in encrypted backup/export of app data.
- Optional: sqlite3mc raw-key configuration to skip the per-open PBKDF2 (~30–85 ms on host).
