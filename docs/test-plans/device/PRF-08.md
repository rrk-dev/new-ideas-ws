# Device verification — PRF-08 Profile & Template Import / Export

The bundle format, verification and round trip are covered on the host by `[PRF-08/AC1]` /
`[PRF-08/AC2]` tests (pure Dart, identical on both platforms). These rows check the OS
integration (share sheet, file picker, registered file type) across platforms.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [PRF-08/AC1] | 1. On iPhone (Pro), create a custom profile with 5 fields. 2. Editor → Export profile → AirDrop/Files to an Android phone (or via a shared folder). 3. On Android, Profiles → Import profile → pick the `.vvprofile`. 4. Open the imported profile and compare every field, instruction and the generated note of a test recording with the iPhone. | Import dialog shows "Adds this profile…"; the profile opens with identical name, fields, instructions, examples; notes render identically. | iPhone 12+ → Pixel 6+ | iOS 17+ → Android 14+ | ⏳ | | |
| [PRF-08/AC1] | Same as above in the other direction (Android → iPhone; iPhone imports via Files → Import profile). | Identical profile on iPhone. | Pixel 6+ → iPhone 12+ | Android 14+ → iOS 17+ | ⏳ | | |
| [PRF-08/AC1] | Tap a `.vvprofile` in iOS Files and in an Android file manager. | VaultVoice is offered as the app for the file type (UTI `com.vaultvoice.profile` / intent filter). Handing the opened file to the importer is a follow-up (PRF-11); import via the in-app picker works. | iPhone / Pixel | iOS 17+ / Android 14+ | ⏳ | | |
| [PRF-08/AC2] | With an enterprise license whose org key signed a pack (LIC-03), import the pack; then import a copy whose `profile.yaml` was edited in a zip tool. | Signed pack: imported as managed / read-only. Edited copy: "This profile pack was changed after signing and cannot be imported."; nothing installed. | any | iOS 17+ / Android 14+ | ⏳ | | |

## Notes / evidence
AC2 on devices needs LIC-03 (enterprise license with `org_profile_pubkey`); until then
`orgProfileKeysProvider` trusts no key and every signed pack is refused as "unknown organization".
