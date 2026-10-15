# Device verification — APP-01 Onboarding & Permission Flow

Host tests cover the flow logic (`app/test/widget/onboarding_test.dart`: redirect on first
launch, consent acknowledgement, notification denial → "Open settings", mobile-data decline,
refused folder → "Keep notes in the app", microphone priming once + denied recovery, offline mode
→ import tile, accessibility of every step at 1× and 2× text) and the bundle / waker logic
(`app/test/unit/onboarding/onboarding_logic_test.dart`). These rows need real people and real
OS prompts, which could not be run when this was authored (no devices, no Xcode / Android SDK).

AC1 is a moderated usability test: 5 participants who have never used VaultVoice, each on a
freshly installed build, no help from the moderator ("think aloud"; the moderator only reads the
task card: *"Set up the app and save your first voice note into a folder of your choice."*).
"Complete" = reaches the Record tab with the consent acknowledged and a folder chosen or "Keep
notes in the app" picked, within 5 minutes, without asking for help.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [APP-01/AC1] Usability (iOS, 3 participants) | 1. Delete the app, install the prod build. 2. Hand over the phone with the task card. 3. Time from first launch to the Record tab; note every hesitation > 10 s and every question. 4. After the session ask: "Where does your audio go?" and "When does the app use the internet?" | 3/3 complete without help in < 5 min. Each participant answers "stays on the phone" and "only to download the AI models" (privacy explainer understood). No OS microphone prompt appears during onboarding. | iPhone 11 or newer | iOS 16+ | | | |
| [APP-01/AC1] Usability (Android, 2 participants) | Same steps 1–4. | 2/2 complete without help in < 5 min; same answers; no microphone prompt during onboarding. | arm64 Android | API 26+ | | | |
| [APP-01/AC2] Deny everything (iOS) | 1. Fresh install. 2. Notifications step: "Allow notifications" → Don't Allow. 3. Models: on cellular only, tap Download → "Wait for Wi-Fi". 4. Folder: open the picker and cancel; then "Keep notes in the app for now". 5. Ready → "Make my first recording"; tap Record → priming dialog → Continue → OS prompt → Don't Allow. 6. Tap "Open settings" on the notice; allow the microphone in Settings; return. | 2: the notice "Notifications are off …" with "Open settings" appears; Continue works. 3: nothing downloads, snack explains how to resume. 5: Record shows the microphone notice; Library/Profiles/Settings/import still work. 6: Settings opens on VaultVoice's page; after allowing, Record works without reinstall. | iPhone | iOS 16+ | | | |
| [APP-01/AC2] Deny everything (Android) | Same steps 1–6 (Android 13+: the notification prompt is the POST_NOTIFICATIONS runtime prompt; choose "Don't allow"). Also on one API 26–32 device (no notification prompt). | Same as iOS; "Open settings" opens *App info › VaultVoice*. | arm64 Android 13+ and one API 26–32 | API 26+ | | | |
| [APP-01] Download while exploring | 1. Fresh install on Wi-Fi. 2. Models step → Download; Continue immediately. 3. Finish onboarding, record a 30 s note while the download is still running. 4. Wait for the download to finish. | The download keeps running (progress visible on the models step / Settings › Models); the recording waits ("Waiting for a model") and is processed automatically once the models are installed, without user action. | iPhone + arm64 Android | iOS 16+ / API 26+ | | | |

## Notes / evidence
Session notes (anonymised participant ids, timings, quotes) and screen recordings go under
`docs/test-plans/device/evidence/APP-01/`. Never record participants' own conversations.
