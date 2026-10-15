# Device verification — SEC-01 Encryption at Rest

Decision and threat boundary: `docs/adr/ADR-SEC-01-file-encryption.md` (OS file encryption for
audio/rendered notes + sqlite3mc-encrypted database). Host evidence: `[SEC-01/AC1]`,
`[SEC-01/AC2]` in `app/test/unit/security/encryption_at_rest_test.dart`.

Use a **dev debug build** (debuggable, so `run-as` / Xcode container download work) with one
finished recording whose transcript contains a known marker phrase (say "purple elephant
seventeen" while recording).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-01/AC1] | Android: 1. Record + process the marker recording. 2. Force-stop the app. 3. `adb exec-out run-as com.vaultvoice.vaultvoice.dev tar -c files/vv no_backup > vv.tar` and extract. 4. `grep -rla "purple elephant" .` ; `head -c 16 files/vv/db/vaultvoice.sqlite \| xxd`. 5. `adb backup` / `bmgr backupnow` the package. | 4: no match in `db/` (incl. `-wal`); DB header is random bytes, not `SQLite format 3`. Only `audio/**.wav` and `rendered/*.md` may contain content (accepted residual risk, ADR "What the ACs mean"). `no_backup/vv_keys/db.v1.key` is 44 bytes of ciphertext. 5: backup contains no app files. | Pixel 7 / any Android 14 arm64 | Android 14 | ⏳ | | |
| [SEC-01/AC1] | iOS: 1. Record + process the marker recording. 2. Xcode → Devices → Download Container. 3. `grep -rla "purple elephant" AppData/Library/Application\ Support/vv/db`; `head -c 16 …/vaultvoice.sqlite \| xxd`. 4. `xattr`/Finder: check `vv/` "Exclude from backup"; Settings → iCloud backup size of the app = 0. | No match in `db/`; header not `SQLite format 3`; `vv/` excluded from backup. | iPhone 12+ | iOS 17/18 | ⏳ | | |
| [SEC-01/AC1] | Both: Settings → Privacy → Encryption. | Subtitle "On — the database is encrypted …"; the dialog says vault exports are plain Markdown. | both above | — | ⏳ | | |
| [SEC-01/AC2] | iOS: 1. Reboot, unlock once. 2. Start a recording, lock the phone for 10 min (Data Protection keys for `completeUntilFirstUserAuthentication` stay available). 3. Unlock, stop, process. 4. Kill the app while locked, then start processing from the notification later while locked. | Chunk files written continuously while locked (duration ≈ 10 min, no gap markers other than ones expected by AUD-04); DB opens while locked (no "Unavailable" in Settings, pipeline runs). | iPhone 12+ | iOS 17/18 | ⏳ | | |
| [SEC-01/AC2] | Android: same as iOS, screen off 10 min with the microphone FGS running; then reboot, **unlock once**, and confirm the DB opens. | Recording continues while locked; Keystore unwrap works while locked (no user-auth key). | Pixel 7 + one low-end (e.g. Galaxy A14) | Android 14 / 13 | ⏳ | | |
| [SEC-01/AC2] | Android: StrongBox device — logcat/diagnostics show no `keystore` error; Settings shows "On". Measure cold start → DB first query. | Works with StrongBox; first open ≤ 400 ms. | Pixel 7 (StrongBox) | Android 14 | ⏳ | | |

## Notes / evidence
Put screenshots / `xxd` output under `docs/test-plans/device/evidence/SEC-01/`.
