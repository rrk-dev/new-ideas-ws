# Device and human verification — LEG-01 legal documents

Authored without a device. Fill Device/OS/Result/Date/Tester only after
running; never copy a result from another row.

| ID | AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|---|
| LEG-01-D1 | [LEG-01/AC2] | Fresh install on iPhone, then macOS, then Android. Launch with airplane mode on. | The acceptance screen appears; Continue stays off until both boxes are ticked and Agree is tapped; the app works offline afterwards. | iPhone, Mac, Android | iOS 16+, macOS current, API 26+ | ⏳ | | |
| LEG-01-D2 | [LEG-01/AC3] | Upgrade an existing install (older build with data). Then ship a build with a new `kLegalVersion`. | Existing user is asked once; after accepting, not asked again until the version changes. | iPhone, Android | iOS 16+, API 26+ | ⏳ | | |
| LEG-01-D3 | [LEG-01/AC4] | Settings → About → Terms of use, then Privacy policy; read both in the gate screen too. | Both open from the bundled text; no browser opens; no network request in the Network activity screen. | iPhone, Android | iOS 16+, API 26+ | ⏳ | | |
| LEG-01-D4 | [LEG-01/AC1] | **Human (owner):** a qualified lawyer reviews both documents using the checklist in `docs/legal/README.md`. | Written approval or requested changes recorded. | n/a | — | ⏳ | | |
| LEG-01-D5 | [LEG-01/AC7] | **Human (owner):** remove the draft banner (`kLegalReleaseApproved` and/or the banner lines), replace `[CITY, INDIA]`, confirm the entity exists. | In-app text shows no DRAFT banner and no placeholder. | iPhone, Android | — | ⏳ | | |
| LEG-01-D6 | [LEG-01/AC7] | **Human (owner):** host both documents at public URLs and enter them in App Store Connect and Play Console; check the age rating against 21+. | URLs load; store answers match `docs/privacy-audit.md`. | n/a | — | ⏳ | | |
