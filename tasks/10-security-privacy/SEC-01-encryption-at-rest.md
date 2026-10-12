# SEC-01 — Encryption at Rest

**Workstream:** Security & Privacy | **Phase:** 2–3 | **Size:** M | **Depends on:** FND-04, AUD-01 | **Source:** Gap (HIPAA/legal positioning in §2.1, §6.1 requires it)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-local-database, vv-decision-records, vv-audio-capture, vv-ffi-bridge, vv-testing

## Goal
Audio, transcripts and the database are encrypted on device, beyond default OS protection.

## Scope
- [ ] Encrypted SQLite for the drift database (sqlite3 v3 build hooks: `sqlite3mc` recommended or `sqlcipher` — decide in ADR); key in iOS Keychain / Android Keystore (hardware-backed where available).
- [ ] iOS Data Protection class `completeUntilFirstUserAuthentication` for files (`complete` blocks background recording — document trade-off).
- [ ] **Phase-1 design step (before AUD-01 finishes):** ADR `ADR-SEC-01-file-encryption` deciding OS file encryption only (iOS Data Protection + Android credential-encrypted storage) vs app-level `vvenc` framed AES-256-GCM format (spec in `vv-audio-capture` → Chunk writer).
- [ ] If `vvenc`: iOS **and** Android encrypt audio chunks, rendered Markdown and work files with a per-file key wrapped by the Keychain/Keystore master key (custom AES-GCM; Jetpack Security is deprecated); native reader decrypts in the bridge (`vv_key`), playback via decrypting `StreamAudioSource`.
- [ ] Exclude app data from cloud backups by default; opt-in encrypted backup/export (stretch).
- [ ] Note: exported vault Markdown is intentionally plaintext (user-controlled); state clearly in UI.

## Acceptance Criteria
- Pulling app container files from a debug/rooted device shows no plaintext transcripts or audio.
- Background recording still works with chosen protection class.
