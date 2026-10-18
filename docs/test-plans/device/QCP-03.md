# Device verification — QCP-03 Android quick capture

QCP-03 adds a home-screen widget, a Quick Settings tile and a static launcher shortcut that only open
Lumen on the Record screen (navigate-only, `docs/adr/ADR-QCP-01-quick-capture.md`). The agent had no
Android SDK and no device, so nothing below has been run; CI only builds the debug APK. Fill
Device/OS/Result/Date/Tester after running. Evidence goes under
`docs/test-plans/device/evidence/QCP-03/`.

Facts verified against developer.android.com (2026-10-18): `TileService` needs
`android.permission.BIND_QUICK_SETTINGS_TILE` and the `QS_TILE` action; `startActivityAndCollapse(Intent)`
is deprecated in API 34 and throws `UnsupportedOperationException` there, and
`startActivityAndCollapse(PendingIntent)` was added in API 34; static shortcuts need `shortcutId`,
`shortcutShortLabel` and an intent with `targetPackage`/`targetClass`, declared through
`android.app.shortcuts` meta-data on the launcher activity. Widget: plain `AppWidgetProvider` +
`RemoteViews` (works at minSdk 26, no Compose; Glance needs Compose and its minimum SDK was not
confirmed). Unverified: the widget receiver's `android:exported="false"` (D1), BAL behaviour of the tile
PendingIntent on API 34–36 (D6).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [QCP-03/AC1] API 26–30 | Add the widget and use the launcher long-press shortcut; tap each. Then tap Record in the app and stop after 10 s. Add the tile too. | Each opens the app on Record with no recording; the in-app tap records with the ongoing notification; WAV appears in the Library. | Android 8–11 phone | 26–30 | ⏳ | | |
| [QCP-03/AC1] API 31–33 | Same as above. | Same. | Android 12–13 phone | 31–33 | ⏳ | | |
| [QCP-03/AC1] API 34+ | Same; for the tile, pull down Quick Settings, tap the tile unlocked, then locked. | App opens on Record, Quick Settings collapses, no `startActivityAndCollapse` exception and no background-activity-launch block in logcat. | Pixel API 34, 35, 36 | 34+ | ⏳ | | |
| [QCP-03/AC3] | Place a call to the phone (ringing, then active). Open Lumen from the widget/tile/shortcut and tap Record. | Recording refuses (CallGuard); nothing starts on its own. | Android phone | 26+ | ⏳ | | |
| [QCP-03/AC5] | Record and process several notes, then look at the widget, tile and shortcut labels. | Only the static "Record"/"Lumen" text; no title, counts or times. | Android phone | 26+ | ⏳ | | |
| [QCP-03/AC4] D1 | Add the widget from the launcher picker on a stock and a Samsung launcher. | Widget is listed and its tap opens the app (confirms `exported="false"` receiver works). | Pixel + Samsung | 26+ | ⏳ | | |
| [QCP-03/AC4] D6 | Tile tap on API 34, 35, 36, unlocked and with the keyguard showing. | Activity opens in the foreground; record whether the device asks to unlock. | Pixel | 34+ | ⏳ | | |
| [QCP-03/AC4] D10 | Force-stop the app, tap each entry point 10 times, time tap to Record screen (60 fps screen recording). | Median and max recorded; max below the 10 s expiry, otherwise the expiry is revised. | Oldest supported phone (API 26) | 26+ | ⏳ | | |
| [QCP-03/AC4] D12 | Tap the widget, kill the app before it opens, wait over 10 s, launch from the icon; also open Lumen from Recents after a widget open. | App opens normally, Record not forced, microphone stays off. | Android phone | 26+ | ⏳ | | |
| [QCP-03/AC4] D13 | Open the Quick Settings tile while Lumen is already in the foreground and tap it. | Record screen is shown (the hand-off is polled on resume; record whether a resume event happens when the shade is pulled). | Android phone | 26+ | ⏳ | | |

## Not run

No Android unit tests were added: the Android SDK is not installed here and CI's android job only
assembles the APK. The Kotlin store logic mirrors the iOS store (`QuickCaptureStore.swift`), which a
`swiftc` harness checked; a JVM unit test is a follow-up. Android has no separate "quick capture
shortcut" row for API < 25 because minSdk is 26.
