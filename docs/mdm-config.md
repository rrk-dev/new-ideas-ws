# Managed configuration (MDM) — admin guide

Lumen reads an organisation's managed configuration at start-up and whenever the OS reports a
change. Every key **can only tighten** the app (SEC-09): no key starts a recording, hides the
recording indicator, or disables the call guard or a consent step. A missing, wrongly typed or
out-of-range value is ignored (the app shows nothing about its content) and never loosens a
default. Encryption at rest is always on and has no key. Nothing is fetched from a URL.

Settings that an organisation forces or locks appear read-only with "Managed by your
organization". Settings also shows a status tile (licence installed/rejected, number of profile
packs installed/rejected). Status text contains counts only, never content.

## Keys

| Key | Type | Effect |
|---|---|---|
| `license` | string | `.vvlicense` file text or its base64 (LIC-03). Verified offline; a licence that does not verify is rejected (fail closed). |
| `profile_packs` | list of base64 `.vvprofile` strings (Android: `bundle_array` with a `pack` string) | Installed as organisation profiles **only if signed** by the key in the installed licence (`org_profile_pubkey`). Unsigned or tampered packs are rejected. A URL anywhere in the list rejects the whole key. Up to 20 packs. A file variant is not supported (deferred). |
| `allowed_target_kinds` | list of `saf`, `bookmark`, `app_local` | Vault folders of other kinds cannot be picked and existing ones receive no writes (exports stay queued). `app_local` is always allowed. |
| `audio_retention_days` | int 1–3650 | Forces audio retention to N days; the setting is locked. |
| `network_disabled` | bool | `true` turns the app's network off (models sideload-only). `false` has no effect. |
| `lock_settings` | list of setting keys | Those settings are read-only. Unknown keys are ignored. |
| `force_app_lock` | bool | `true` forces the app lock on. |
| `disable_custom_models` | bool | `true` disables sideloaded custom models. |
| `force_consent_confirmation` | bool | `true` always asks for recording-consent confirmation. |
| `max_recording_minutes` | int 1–480 | Stops a recording after N minutes. The recorder uses the smaller of this and its own limit, so it can only shorten a recording. |

Bool values may be `true`/`false` or the strings `"true"`/`"false"`. Unknown keys are ignored.

## Delivery per platform

| Platform | Mechanism | Status |
|---|---|---|
| iOS | Managed App Configuration: the dictionary under `UserDefaults` key `com.apple.configuration.managed`; change signal `UserDefaults.didChangeNotification`. | Documented by Apple; not yet run on a device (no MDM available). |
| macOS | The same `com.apple.configuration.managed` key, plus keys forced into the app's preference domain by a configuration profile. | **Unverified.** Apple's declarative `com.apple.configuration.app.managed` (with an `AppConfig` key) is documented for iOS 18.4+/macOS 27.0+ in apple/device-management; delivery of managed app configuration to `UserDefaults` on earlier macOS releases could not be confirmed from Apple's documentation. See the device checklist. |
| Android | `RestrictionsManager.getApplicationRestrictions()` using the schema in `res/xml/app_restrictions.xml` (`android.content.APP_RESTRICTIONS` meta-data). A receiver registered at runtime re-reads on `ACTION_APPLICATION_RESTRICTIONS_CHANGED` (manifest receivers do not get it). | Built by CI only; not yet run on a device. |

## Known limits

- Until the configuration has been read once, the vault-folder restriction is not applied
  (the read takes milliseconds at start-up). Network, retention, app lock, consent and the
  recording cap read the source directly when they act.
- The verified licence is held in memory (LIC-03); MDM re-installs it on every start.
- On Android the MDM console may render `bundle_array` and `multi-select` differently; a
  console that cannot should be configured through its custom-JSON option.

## Testing

Host tests: `app/test/unit/licensing/managed_config_test.dart` and the `[LIC-04/AC1]` tests in
`settings_screen_test.dart` and `recording_controller_test.dart`. On device see
`docs/test-plans/device/LIC-04.md`.
