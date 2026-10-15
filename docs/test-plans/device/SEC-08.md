# Device verification — SEC-08 Threat Model & Pre-Launch Security Review

Threat model: [../../threat-model.md](../../threat-model.md). Host evidence:
`[SEC-08/AC1]` in `tools/ci/tests/test_sec08_threat_model.py`. The rows below are the
launch gate steps that need a person, a release build or a libFuzzer host. All ⏳.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-08/AC1] | Build the release candidate. Run MobSF on the APK and IPA. Triage each High finding in the threat-model Findings table. | No unresolved High or Critical. Decisions recorded per finding. | Release APK + IPA | n/a | ⏳ | | |
| [SEC-08/AC1] | Send crafted VIEW/SEND intents (wrong MIME, 2 GB file, `../` names) with `adb shell am start`. Check `dumpsys package` for exported components. | Nothing starts recording; oversized or bad files are rejected without a crash. | Pixel or Samsung | Android 14+ | ⏳ | | |
| [SEC-08/AC1] | Install the user CA of an intercepting proxy; use the app through a full session including a model download. Then edit the catalog, flip a byte in a model and swap the signature. | Only catalog/CDN traffic appears; tampered files are rejected; nothing is installed. | iPhone and Android phone | current | ⏳ | | |
| [SEC-08/AC1] | Take an `adb backup` and an iTunes/Finder backup after creating a recording and a note. | No recordings, DB or keys readable. | Both platforms | current | ⏳ | | |
| [SEC-08/AC1] | Run `native/fuzz/build_fuzz.sh libfuzzer wav 3600` and `... gguf 3600` on a libFuzzer host. | No crash or sanitizer report. Any crash is High: fix, add the artifact to the corpus, re-run. | Linux or macOS with LLVM | n/a | ⏳ | | |
| [SEC-08/AC1] | Check the first `osv` workflow run on main. | Clean, or each finding triaged in the threat-model Dependency findings table with an expiry. | CI | n/a | ⏳ | | |

## Notes / evidence

Store reports under `docs/test-plans/device/evidence/SEC-08/`. Do not commit reports
that contain keys or user data.
