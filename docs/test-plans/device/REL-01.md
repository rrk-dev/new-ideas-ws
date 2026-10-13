# Verification on GitHub Actions + stores — REL-01 Release Build & Signing Pipeline

The release pipeline cannot run on the authoring machine (no Xcode, Android SDK, fastlane, store
credentials). These rows need the real secrets in the `release` environment
(`docs/release-secrets.md`) and a real tag push.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [REL-01/AC1] | 1. Create all secrets/variables from `docs/release-secrets.md` in the `release` environment. 2. Bump `app/pubspec.yaml` to `X.Y.Z` on `main`. 3. `git tag vX.Y.Z && git push origin vX.Y.Z`. 4. Approve the `release` environment. 5. Wait for `prepare`, `android`, `ios`. | All three jobs green; a build `X.Y.Z (N)` with N = run number + offset appears in TestFlight (internal) and in the Play internal testing track, both signed (Play App Signing accepts the upload key; TestFlight processing succeeds); artifacts `symbols-android-*`, `symbols-ios-*` (with `.symbols`, `obfuscation_map.json`, native symbols, `SHA256SUMS`) and `release-notes` exist. | GitHub Actions ubuntu-latest + macos-latest; App Store Connect; Play Console | runner images | | | |
| [REL-01/AC1] | Negative: push tag `vX.Y.(Z+1)` without bumping pubspec. | `prepare` fails with `tag ... does not match pubspec version`; no build is uploaded. | GitHub Actions | runner images | | | |
| [REL-01/AC1] | Install the uploaded build from TestFlight / Play internal on the oldest + newest matrix device and run the smoke test in `docs/release-checklist.md`. | App launches (prod flavor, obfuscated), records, transcribes, exports. | oldest + newest per `docs/device-matrix.md` | iOS 16+/Android 8+ | | | |

## Notes / evidence
Locally verified: `python3 -m pytest tools/release/tests` (workflow structure, secrets documented,
no committed key material, obfuscation flags, versioning, changelog). The Fastfiles, `signing.gradle`
and `release.yml` were written without being executed (fastlane, Xcode and the Android SDK are not
installed on the authoring machine).
