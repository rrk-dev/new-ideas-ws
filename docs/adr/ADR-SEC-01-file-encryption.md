# ADR-SEC-01 — Encryption at rest: OS file encryption + sqlite3mc-encrypted database (v1)

- **Status:** Proposed (host-verified; no physical-device run yet — see Evidence)
- **Date:** 2026-10-14
- **Task:** SEC-01
- **Deciders:** Claude Code (implementer); pending independent verifier + human
- **Supersedes:** —

## Context
VaultVoice keeps recordings (16 kHz WAV chunks, AUD-01), transcripts, extractions, settings and
vault handles on the device (`<appSupport>/vv/`, ADR-FND-04). The product promise and the
HIPAA/legal positioning (§2.1, §6.1 of the master plan) want this data protected beyond "the
phone has a passcode". Hard constraints:

- **Background recording and processing must keep working while the device is locked**
  (AUD-04 iOS background audio, AUD-05 Android microphone FGS, FND-05 pipeline). A protection
  class or key that is unavailable while locked breaks recording mid-session.
- whisper.cpp reads chunk files **by path inside the native bridge** (STT-03
  `vv_stt_transcribe_async`); llama.cpp never touches audio. Any app-level audio format must be
  decrypted in C (`vv_key`) without plaintext temp files.
- One process-wide DB connection on a drift background isolate (ADR-FND-04); the cipher hook
  (`DatabaseCipher.apply`) runs first on that isolate.
- No new network SDKs; licenses must allow closed-source commercial distribution.

Two independent decisions:
1. **Database:** which encrypted SQLite build (`sqlite3` 3.7.0 build hooks offer `sqlite3mc`
   and `sqlcipher`).
2. **Files (audio chunks, `rendered/*.md`, `work/`):** OS file encryption only, or app-level
   `vvenc` (framed AES-256-GCM, spec in `vv-audio-capture` → Chunk writer).

## Options
Database:
- **D1. SQLite3 Multiple Ciphers (`source: sqlite3mc`)** — drift-recommended; MIT; same SQLite
  version as the default build (3.53.4); ChaCha20-Poly1305 default cipher.
- **D2. SQLCipher community (`source: sqlcipher`)** — BSD-style; links OpenSSL on Android
  (larger, extra license notice); may lag the upstream SQLite version (sqlite3 `doc/hook.md`).
- **D3. Plain SQLite on OS file encryption only.**

Files:
- **F1. OS file encryption only** — iOS Data Protection
  `NSFileProtectionCompleteUntilFirstUserAuthentication` on `vv/`; Android credential-encrypted
  storage (file-based encryption of `filesDir`, mandatory on Android 10+ devices).
- **F2. App-level `vvenc`** — per-file key wrapped by a Keychain/Keystore master key, native
  decrypting reader in the bridge, decrypting `StreamAudioSource` for playback, crypto-shredding.
- **F3. `vvenc` for Dart-only files (`rendered/`, `work/`) + OS encryption for audio.**

## Criteria (weights fixed before evaluating)
| Criterion | Weight |
|---|---|
| Protection against the realistic threats (lost/stolen device, backups, other apps, forensic image of a locked device) | 30% |
| Background recording/processing while locked keeps working | 25% |
| Integration effort / risk (native bridge, STT, playback, recovery, other groups' code) | 20% |
| Performance + binary size | 10% |
| License & maintenance | 10% |
| Testability on host | 5% |

## Evidence
Environment: macOS 27 host, Apple M3 Pro, Flutter 3.47.7 (FVM), `drift` 2.35.2, `sqlite3` 3.7.0
with `hooks: user_defines: sqlite3: source: sqlite3mc`. No physical device available.

| Check | Result |
|---|---|
| Hook build selects sqlite3mc on host | `PRAGMA cipher` → `chacha20`; `sqlite_version()` 3.53.4; FTS5 compiled in (`app/test/unit/security/encryption_at_rest_test.dart`) |
| Transcript text absent from every file in `vv/` after writes (DB + `-wal` + `-shm`) | ✅ `[SEC-01/AC1]` test, byte scan for the segment text and for the `SQLite format 3` header |
| Wrong key / no key | open refused (`SQLITE_NOTADB` → `StorageFailure`) before any query |
| Pre-SEC-01 plaintext DB | detected by header, `journal_mode=DELETE` + `PRAGMA hexrekey` → encrypted in place, data preserved, WAL back on (`[SEC-01/AC1]` test) |
| Host library size | `libsqlite3mc.dylib` 1 958 112 B vs `libsqlite3.dylib` 1 713 824 B (+244 KB, macOS arm64) |
| Insert 20 000 rows in one transaction | plain 228 ms, sqlite3mc 129 ms (noise; no measurable penalty) |
| Full scan 20 000 rows | plain 132 ms, sqlite3mc 86 ms |
| Open + first query (PBKDF2-SHA256 page-key derivation, sqlite3mc default) | plain 0.3–6 ms, sqlite3mc 32–85 ms per open (one open per process) |
| Key never printed | `VaultKey` / `Sqlite3mcCipher.toString()` redact; native errors carry only OSStatus / exception class |

Not measured (device-only, ⏳ rows in `docs/test-plans/device/SEC-01.md`): open latency on a
low-end Android phone (expected ≤ 4× host), Keystore/StrongBox unwrap latency, background
recording while locked with the chosen class, a container pull from a debuggable build.

Raw data: the timing probe was a throw-away `flutter test` script (numbers above); the tests are
the reproducible evidence.

### Scoring (1–5)
| Criterion (weight) | D1 sqlite3mc | D2 sqlcipher | D3 none |
|---|---|---|---|
| Threats (30) | 5 | 5 | 2 |
| Background (25) | 5 | 5 | 5 |
| Effort (20) | 5 | 4 | 5 |
| Perf/size (10) | 4 | 3 | 5 |
| License (10) | 5 | 4 | 5 |
| Testability (5) | 5 | 4 | 5 |
| **Total** | **4.90** | 4.45 | 4.10 |

| Criterion (weight) | F1 OS only | F2 vvenc | F3 hybrid |
|---|---|---|---|
| Threats (30) | 3 | 5 | 3.5 |
| Background (25) | 5 | 5 | 5 |
| Effort (20) | 5 | 1 | 3 |
| Perf/size (10) | 5 | 3 | 4 |
| License (10) | 5 | 5 | 5 |
| Testability (5) | 5 | 3 | 4 |
| **Total** | **4.40** | 3.90 | 4.00 |

## Decision
**Database: D1 — SQLite3 Multiple Ciphers.** `app/pubspec.yaml` sets
`hooks: user_defines: sqlite3: source: sqlite3mc`. `Sqlite3mcCipher`
(`app/lib/core/security/sqlite3mc_cipher.dart`) runs first in
`NativeDatabase.createInBackground(setup:)`: asserts the cipher build (`PRAGMA cipher`), issues
`PRAGMA hexkey`, migrates a legacy plaintext file with `PRAGMA hexrekey`, and probes
`sqlite_master` so a wrong key fails at open. If the key cannot be obtained the app installs
`UnavailableCipher` and the database stays closed — it never falls back to plaintext.

**Key:** a random 32-byte data key per purpose (`db.v1`), via `KeyVault`
(`app/lib/core/security/key_vault.dart`, channel `vaultvoice/secure_storage`):
- iOS (`ios/Runner/SecureStoragePlugin.swift`): Keychain generic password,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (background-readable after first unlock,
  not synced, not migrated to another device).
- Android (`…/security/SecureStoragePlugin.kt`): AES-256-GCM wrap by a non-exportable
  AndroidKeyStore key (StrongBox when `FEATURE_STRONGBOX_KEYSTORE`, else TEE),
  `setUserAuthenticationRequired(false)`; wrapped blob in `noBackupFilesDir/vv_keys/`. Plain
  Keystore + `javax.crypto`, because Jetpack Security is deprecated.

**Files: F1 — OS file encryption only for v1.** `prepareEncryptionAtRest()` (bootstrap) calls
`protectDirectory(vv/)`: iOS sets `FileProtectionType.completeUntilFirstUserAuthentication`
(inherited by new files) and `isExcludedFromBackup`; Android relies on credential-encrypted
`filesDir` (FBE). `.complete` was rejected: the chunk writer must append while the screen is
locked (AUD-04). `AudioChunkCodec` stays `ChunkCodecId.wav`; `vvenc` remains specified behind
that seam for a later task.

**Backups:** Android `allowBackup="false"` + `dataExtractionRules` excluding every domain in
both `<cloud-backup>` and `<device-transfer>` + `fullBackupContent` excluding all (API ≤ 30);
iOS `isExcludedFromBackup` on `vv/` (models already excluded by MDL-02). Encrypted opt-in
backup/export is a stretch item → follow-up.

**Exports:** vault Markdown is plaintext by design (user-controlled folders); Settings →
Encryption says so.

### What the acceptance criteria mean under this decision
- *"Pulling app container files from a debug/rooted device shows no plaintext transcripts or
  audio"*: transcripts, segments, extractions, settings and vault handles live in the encrypted
  DB → no plaintext in a pulled container (host-tested, device row ⏳). Audio chunks and
  `rendered/*.md` are protected by the OS class keys: they are unreadable in a forensic image of
  a device that is off / before first unlock and are never in backups, but **an attacker with
  root on a running, unlocked device (or `run-as` on a debuggable build) can read them**. On
  such a device the Keychain/Keystore-held DB key is reachable through the app's uid as well, so
  `vvenc` would raise the bar only modestly while costing a native decrypting reader in the
  bridge, playback and recovery changes across three other groups' code. This residual risk is
  recorded here and in the device checklist; **PRODUCT-DECISION:** if the user requires the
  strict reading for audio, schedule follow-up SEC-10 (`vvenc` for audio + rendered notes).
- *"Background recording still works with chosen protection class"*: guaranteed by
  construction (after-first-unlock class and keychain accessibility, no user-auth Keystore
  key); verified on device ⏳.

## Consequences
- Positive: everything structured (and searchable) is encrypted with a hardware-protected key;
  no format change for audio, STT, playback, crash recovery or import; ~244 KB library delta;
  wrong/missing keys fail closed and visibly (Settings shows "Unavailable").
- Negative / risks:
  - Plaintext WAV and rendered notes on a rooted unlocked device (above) — mitigation: app
    lock (SEC-03) hides content in-app; SEC-04 retention shortens the window; SEC-10 if needed.
  - iOS Keychain items survive an app reinstall; a new install reuses the old key (harmless:
    the DB was deleted with the app). "Delete all data" deletes the keys (SEC-04).
  - Android Keystore key loss (factory reset of the keystore, rare OEM bugs) makes the DB
    unreadable → app shows "Unavailable"; recovery = Delete all data. No backup exists by design.
  - PBKDF2 on every open (~30–85 ms host); could be removed with a raw-key sqlite3mc config later.
- Follow-up tasks: SEC-10 (`vvenc` audio/rendered encryption, if the strict AC reading is
  required); SEC-11 (opt-in encrypted backup/export, stretch).
