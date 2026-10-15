# Release secrets (REL-01)

The release workflow (`.github/workflows/release.yml`) reads credentials **only** from GitHub
secrets of the `release` **environment** (Settings → Environments → `release`). Nothing secret is
ever committed: `key.properties`, `*.jks`, `*.keystore`, `.p8` and service-account JSON files are
written to the runner's temp directory at run time and deleted at the end of the job.
`tools/release/tests/test_release_pipeline.py` fails if the workflow references a secret that is
not listed here, or if anything that looks like key material is committed.

Recommended environment protection: required reviewer (release manager), deployment branches/tags
limited to `v*.*.*`, no secrets at repository level.

## Secrets

| Secret | Platform | What | How to create |
|---|---|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | Android | Play **upload** keystore (`.jks`), base64 | `keytool -genkeypair -v -keystore upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload`; `base64 -i upload.jks`. Enroll in **Play App Signing** (Google holds the app signing key; a lost upload key can be reset). |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | Android | keystore password | chosen at creation |
| `ANDROID_UPLOAD_KEY_ALIAS` | Android | key alias (e.g. `upload`) | chosen at creation |
| `ANDROID_UPLOAD_KEY_PASSWORD` | Android | key password | chosen at creation |
| `PLAY_SERVICE_ACCOUNT_JSON` | Android | Google Cloud service-account JSON key with the Play Console "Release to testing tracks" permission for this app only | Play Console → Users and permissions → invite the service account |
| `APP_STORE_CONNECT_API_KEY_ID` | iOS | App Store Connect API key ID | App Store Connect → Users and Access → Integrations → Team keys, role **App Manager** |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | iOS | issuer ID shown on the same page | — |
| `APP_STORE_CONNECT_API_KEY_P8` | iOS | the downloaded `AuthKey_<id>.p8`, base64 | `base64 -i AuthKey_XXXX.p8` (the file can be downloaded only once) |
| `APPLE_TEAM_ID` | iOS | 10-character Apple Developer team ID | developer.apple.com → Membership |
| `MATCH_GIT_URL` | iOS | HTTPS URL of the **private** match certificates repo | create an empty private repo |
| `MATCH_PASSWORD` | iOS | passphrase that encrypts the match repo | chosen when running `fastlane match appstore` the first time |
| `MATCH_GIT_BASIC_AUTHORIZATION` | iOS | `base64("<user>:<read-only token>")` for the match repo | fine-grained token, read-only, that repo only |

No Apple ID password or app-specific password is used anywhere (API key only).

## Variables (not secret)

| Variable | Default | Meaning |
|---|---|---|
| `VV_BUILD_NUMBER_OFFSET` | `0` | Added to `GITHUB_RUN_NUMBER` to form the build number (`tools/release/version.py`). Only ever increase it (e.g. after a manual upload used a higher number, or if the workflow is re-created and its run counter restarts). |

## Rotation
- Upload key compromised/lost → Play Console → App integrity → request upload key reset; update the
  four `ANDROID_UPLOAD_*` secrets.
- API key → revoke in App Store Connect, create a new one, update the three `APP_STORE_CONNECT_*`
  secrets.
- Certificates → `fastlane match nuke distribution` + `fastlane match appstore` on the release Mac
  (not CI: CI runs match with `readonly: true`).

## Handling rules
- Never paste secret values in issues, PRs, logs or task files; workflow steps that touch them run
  with `set +x` and write files with `umask 077`.
- Release symbols (Dart `.symbols`, obfuscation map, unstripped `.so`, dSYMs) are **private**
  workflow artifacts — they are not secrets but must not be published (see `docs/release-checklist.md`).

## Purchase verification build configuration

| Secret | Purpose |
|---|---|
| `VV_PLAY_PUBLIC_KEY` | Base64 RSA public licensing key from this app’s Play Console; injected into Android billing build configuration, never committed. |
