# Device verification — LIC-04 Enterprise managed configuration (MDM)

Host tests cover parsing, stricter-only semantics, the channel contract and the enforcement
points (`app/test/unit/licensing/managed_config_test.dart`, settings and recording-controller
tests). These rows need an MDM or the OS managed-configuration tools, which were not available
when this was authored (no MDM server, no Android SDK).

Android: use Android Test DPC or `adb shell am broadcast` is **not** sufficient; set restrictions
through Test DPC. Apple: use an MDM (Jamf/Intune/Apple Configurator profile) pushing the
`com.apple.configuration.managed` dictionary. Config examples are in `docs/mdm-config.md`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LIC-04/AC1] | iOS: push `network_disabled=true`, `force_app_lock=true`, `audio_retention_days=14`, `max_recording_minutes=1`. Open Settings; record. | Those settings show the lock and "Managed by your organization"; network off; lock required; recording stops at 1 min. | iPhone | iOS 16+ | ⏳ | | |
| [LIC-04/AC1] | iOS: change the config while the app runs. | Settings updates without a restart. | iPhone | iOS 16+ | ⏳ | | |
| [LIC-04/AC1] | Android (Test DPC): same keys; add `allowed_target_kinds=[app_local]`. Try to add a vault folder. | Settings shows managed state; folder picker refused with the managed message; recording stops at 1 min. | Pixel | Android 8+ | ⏳ | | |
| [LIC-04/AC1] | Android: change restrictions while the app runs. | Status updates (runtime receiver). | Pixel | Android 8+ | ⏳ | | |
| [LIC-04/AC1] | macOS: deliver the same keys through a configuration profile / managed app config. | Same as iOS. Record which delivery path worked (UserDefaults `com.apple.configuration.managed` vs forced app-domain keys vs declarative `app.managed`). | Mac | macOS 13+ | ⏳ | | |
| [LIC-04/AC1] | Push `license` + one signed `profile_packs` entry and one unsigned entry. | Licence installed; the signed pack appears as an organisation profile; the unsigned one is rejected; status tile shows the counts. | any | any | ⏳ | | |
| [LIC-04/AC1] | Push `force_consent_confirmation=true`. Start a recording. | The consent confirmation is always shown. | any | any | ⏳ | | |

## Notes / evidence
Screenshots under `docs/test-plans/device/evidence/LIC-04/`.
