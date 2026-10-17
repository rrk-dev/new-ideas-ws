# ADR-QCP-01 — Quick capture from outside the app (widget, Lock Screen control, Action Button, Android tile)

- **Status:** Proposed — product/legal decision; QCP-02 and QCP-03 must not start until a human marks this Accepted
- **Date:** 2026-10-17
- **Task:** QCP-01
- **Deciders:** Copilot (author); human approval required (SEC-09 amendments below)
- **Supersedes:** the *proposals* AUD-11 (AUD-08 follow-up), AUD-10 Live Activity (AUD-04 follow-up) and AUD-10 share-extension wiring (AUD-06 follow-up). None is a filed task. No Accepted ADR is edited; ADR-SEC-09 changes are written as amendments for approval.

## Question
How may a user start (or get one step from starting) a recording from outside the app — iOS Home/Lock
Screen widget, iOS Lock Screen / Control Center control, iPhone Action Button, Android widget, Android
Quick Settings tile — without breaking ADR-SEC-09 (user-started only, explicit tap, visible indicator,
no automations, no call recording, standard microphone APIs)?

Product constraints (user): English only, no Apple Watch, no call recording, no automations,
microphone only. Hard constraints: AGENTS.md (iOS 16+ floor, Android API 26+, no network, no content
logging, no new call-related permission/background mode).

## How this was verified
Every platform fact is labelled **[V]** (verified: official page or local SDK, source cited) or **[U]**
(unverified: no official statement found, or needs hardware → a row in
`docs/test-plans/device/QCP-01.md`, "D#").

| Toolchain in this repo / machine | Value | Source |
|---|---|---|
| Xcode | 27.0, build 27A266a (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version`), iOS SDK 27.0 (`xcrun --show-sdk-version`) | local |
| iOS deployment target (Runner) | 16.0 (`app/ios/Runner.xcodeproj`, `IPHONEOS_DEPLOYMENT_TARGET`) | repo |
| macOS deployment target | 13.0 (`app/macos/Runner.xcodeproj`) | repo |
| Flutter / Dart | 3.47.7 via FVM (`app/.fvmrc`) | repo |
| Android compileSdk / targetSdk | 36 / 36 (`flutter.compileSdkVersion`/`targetSdkVersion` in `~/fvm/versions/3.47.7/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`); minSdk 26; NDK 28.2.13676358 (`app/android/app/build.gradle.kts`) | repo + local |
| Android Gradle Plugin / Kotlin / Gradle | 9.1.0 / 2.4.0 / 9.3.1 (`settings.gradle.kts`, `gradle-wrapper.properties`) | repo |
| Android SDK on the authoring machine | not installed (no `platforms/` directory found); Android facts come from docs only | local |
| Xcode extension targets today | `Runner`, `RunnerTests` only; `app/ios/ShareExtension/` has sources + entitlements but **no Xcode target** | repo |

Documentation fetched 2026-10-17 (Apple documentation pages read through the public
`developer.apple.com/tutorials/data/documentation/...json` endpoint behind each page, because the
HTML pages are script-rendered; Apple's support guide and Android pages as HTML):

| # | Page | Used for |
|---|---|---|
| A1 | https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system | Controls: where they appear, button/toggle, Action button, stateless button, auth/redaction |
| A2 | https://developer.apple.com/documentation/widgetkit/controlwidgetbutton | `ControlWidgetButton` availability iOS 18.0; "buttons don't have state … launching an app" |
| A3 | https://developer.apple.com/documentation/widgetkit/staticcontrolconfiguration | iOS 18.0 |
| A4 | https://developer.apple.com/documentation/widgetkit/widgetfamily (+ `/accessorycircular`, `/accessoryrectangular`) | families: system* iOS 14.0; accessory* (Lock Screen) iOS 16.0 |
| A5 | https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity | `widgetURL`/`Link`, URL delivered to the app |
| A6 | https://developer.apple.com/documentation/swiftui/view/widgeturl(_:) | iOS 14.0 |
| A7 | https://developer.apple.com/documentation/appintents/appintent/openappwhenrun | `openAppWhenRun`: iOS 16.0, deprecated 26.0; "generates an error if the app intent runs in an app extension" |
| A8 | https://developer.apple.com/documentation/appintents/appintent/supportedmodes (+ `/intentmodes`) | iOS 26.0 replacement: `.foreground(.immediate)` etc. |
| A9 | https://developer.apple.com/documentation/appintents/appintent/isdiscoverable | iOS 17.0: non-discoverable intent runs from the app UI or a widget; system features (Siri, Spotlight, Shortcuts) cannot access it; App Shortcuts require discoverable |
| A10 | https://developer.apple.com/documentation/appintents/intentsystemcontext (+ `/precisetimestamp`, `/appintent/systemcontext`) | what an intent can learn about its invocation |
| A11 | https://developer.apple.com/documentation/appintents/openurlintent | iOS 18.0; opens a *universal link*; app foregrounded automatically |
| A12 | https://developer.apple.com/documentation/appintents/intentauthenticationpolicy | `alwaysAllowed` default runs "including when the device is locked"; `requiresLocalDeviceAuthentication` (iOS 16.0) |
| A13 | https://support.apple.com/guide/iphone/iphe89d61d66/ios | Action button: "on supported models", press and hold, options incl. Controls / Shortcut |
| A14 | https://support.apple.com/guide/iphone/control-access-to-hardware-features-iph168c4bbd5/ios | orange microphone indicator |
| A15 | https://developer.apple.com/documentation/xcode/configuring-app-groups | App Groups: needed to share data between an extension and its host app |
| A16 | https://developer.apple.com/support/compare-memberships/ | free "Personal Team" limits |
| A17 | https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord | background audio needs `UIBackgroundModes: audio` (already in the app, AUD-04) |
| G1 | https://developer.android.com/develop/ui/views/appwidgets/overview | RemoteViews widgets vs Jetpack Glance |
| G2 | https://developer.android.com/develop/ui/compose/glance | "Glance requires Compose to be enabled"; "in active development" |
| G3 | https://developer.android.com/reference/android/service/quicksettings/TileService | TileService API 24; `BIND_QUICK_SETTINGS_TILE`; `startActivityAndCollapse(Intent)` deprecated API 34 and **throws `UnsupportedOperationException` on API 34+**; use `startActivityAndCollapse(PendingIntent)` |
| G4 | https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start | FGS start-from-background and while-in-use (microphone) rules |
| G5 | https://developer.android.com/develop/background-work/services/fgs/service-types | microphone FGS: `RECORD_AUDIO` granted; cannot create a microphone FGS while in the background |
| G6 | https://developer.android.com/guide/components/activities/background-starts | background activity launch (BAL) exceptions incl. widget/launcher; PendingIntent opt-in hardening |
| G7 | https://developer.android.com/reference/android/content/pm/ShortcutManager and https://developer.android.com/develop/ui/views/launch/shortcuts | launcher shortcuts (API 25); only main/launcher activities |

## Verified platform facts

### iOS
| Fact | Label |
|---|---|
| Home Screen widgets (`systemSmall`…) exist since iOS 14.0; Lock Screen widgets (`accessoryCircular/Rectangular/Inline`) since iOS 16.0 — both within the app's iOS 16 floor. A tap opens the containing app and passes the `widgetURL`/`Link` URL (or an `NSUserActivity`) to the app. | **[V]** A4, A5, A6 |
| Controls (Control Center, Lock Screen, Action button) are `ControlWidget`s using `ControlWidgetButton`/`StaticControlConfiguration`, **iOS 18.0+**. They live in a widget extension. A control button "performs its action using an app intent" and can launch the app. Buttons are stateless. A control can require device authentication and redact text when locked. A Control cannot be offered below iOS 18 (iOS 16/17 devices only get the widget). | **[V]** A1, A2, A3 |
| The app must still build for iOS 16: Controls need `@available(iOS 18.0, *)` guards inside the extension. Not compiled here. | **[U]** D1 (build with Xcode 27 SDK at deployment target 16.0) |
| Action button: Apple's guide says only "on supported models"; press-and-hold runs the assigned action; the options include **Controls** ("access your favorite control") and **Shortcut** ("open an app or run your favorite shortcut"); for those two the user must pick a specific item or the button does nothing. | **[V]** A13 |
| Which iPhone models have an Action button, and the lowest iOS that offers the *Controls* option on it. Apple's pages fetched do not enumerate models. Third-party search results say iPhone 15 Pro and later; this is **not** used as evidence. | **[U]** D2 |
| `openAppWhenRun` exists since iOS 16.0, is deprecated in iOS 26.0 (use `supportedModes`), and "generates an error if the app intent runs in an app extension". `supportedModes` is iOS 26.0+ only. So an intent that must open the app has to be compiled into/run by the app, and the iOS 16–25 and 26+ spellings differ. | **[V]** A7, A8 |
| `OpenURLIntent` (iOS 18.0) foregrounds the app automatically but opens a **universal link** (needs an associated domain — not wanted: no domain/network dependency). | **[V]** A11 |
| A non-discoverable intent (`isDiscoverable = false`, iOS 17.0+) "can run from your app's interface or from a widget, but system features can't access it"; App Shortcuts need discoverable intents. Apple does not say what "system features" means for the Action button. The Action button's **Controls** option picks a *control* (a widget), not an intent. | **[V]** A9; Action-button interplay **[U]** D3 |
| An intent's `systemContext` exposes `currentMode` (iOS 26), `isVoiceOnly`, `locale`, `preciseTimestamp`. `preciseTimestamp` is documented only for the Action button on **Apple Watch Ultra**. **No documented API tells an iOS App Intent whether it came from a physical Action-button press, a Lock Screen/Control Center tap, a Shortcut, or a Shortcuts automation.** | **[V]** A10 (absence) |
| `authenticationPolicy` defaults to `alwaysAllowed` ("including when the device is locked"); `requiresLocalDeviceAuthentication` makes the system ask to unlock first. | **[V]** A12 |
| Whether a microphone session can be started by an intent that runs while the app is *not* foreground. Apple documents no such path in the pages above; `RecordingController` refuses unless `AppLifecycleState.resumed` anyway, so this ADR does not rely on it. | **[U]** D4 (negative test) |
| iOS shows an orange indicator "whenever an app uses the microphone without the camera". | **[V]** A14 |
| App Groups are the documented way for an extension and its host app to share data (`UserDefaults(suiteName:)`, container URL). A group id must start with `group.`; the capability must be added to both targets and registered. | **[V]** A15 |
| Free "Personal Team": up to 10 App IDs and 3 devices, expiring after 7 days, 3 apps per device, profiles expire after 7 days. Apple's page does **not** say whether App Groups, or app extensions, can be signed with a Personal Team. | **[V]** A16 (limits); App Groups / extension signing **[U]** D5 |
| The repo already needs an App Group for the future ShareExtension (`group.$(APP_BUNDLE_IDENTIFIER)` in `app/ios/ShareExtension/ShareExtension.entitlements`) and the memory entitlement `com.apple.developer.kernel.increased-memory-limit` (`Runner.entitlements`) which already requires a portal-registered App ID. | repo |

### Android
| Fact | Label |
|---|---|
| App widgets: classic `RemoteViews`/XML (AppWidgetProvider) or Jetpack Glance (Compose-style Kotlin API). Glance "requires Compose to be enabled", "is in active development". Glance's minimum SDK was not confirmed (reference page 404). The app has no Compose today (Flutter UI). | **[V]** G1, G2; Glance minSdk **[U]** |
| `TileService`: API 24 (app minSdk 26 is fine); service must require `android.permission.BIND_QUICK_SETTINGS_TILE`. On API 34+ `startActivityAndCollapse(Intent)` throws `UnsupportedOperationException`; the `PendingIntent` overload (API 34) must be used. | **[V]** G3 |
| Launcher static/dynamic shortcuts: `ShortcutManager` API 25; only activities with `ACTION_MAIN` + `CATEGORY_LAUNCHER` can have shortcuts. | **[V]** G7 |
| Android 12+ (target ≥ 31) apps cannot start an FGS from the background except documented exemptions. On Android 14+ an FGS of type `microphone` needs `RECORD_AUDIO` *at creation*; because it is a while-in-use permission, "you must call `startForegroundService()` … while your app has a visible activity" unless an exemption applies. Exemptions listed include: started by interaction with an **app widget**, by interaction with a **notification**, by a system component, by a PendingIntent sent from a different *visible* app. **A Quick Settings tile tap is not named** among the exemptions. | **[V]** G4, G5 |
| Background Activity Launch is exempt when "initiated by the device's launcher app … or interacts with a widget", or when a PendingIntent is sent by the system; PendingIntent launches have new opt-in rules (creator or sender must opt in to BAL privileges). | **[V]** G6 |
| Exactly what `TileService.startActivityAndCollapse(PendingIntent)` requires on Android 14/15/16 devices (BAL opt-in flags, behaviour on a locked device), and whether a mic FGS started from a tile tap would be allowed. | **[U]** D6, D7 |
| FGS must show a persistent notification (AUD-05 already does). | **[V]** G6 ("A foreground service must display a persistent notification") |

## Options
- **A. Navigate-only everywhere.** The outside surface only brings the app to the Record screen, "ready to
  start". The start is the existing in-app Record tap (`StartSource.inAppButton`).
- **B. Start-now everywhere.** A fresh single-use request starts the recording once the app is foreground,
  through the shared consent flow (one tap from outside when no dialog is pending).
- **C. Hybrid.** Navigate-only where provenance or a background microphone start cannot be established
  (iOS widget, Control, Action button); start-now where the platform gives a documented user-tap path
  (Android widget, Android tile), gated on the device rows below passing.
- **D. Do nothing** (in-app only; rejected: user asked for quick capture).

### Weighted criteria (set before scoring)
| Criterion | Weight |
|---|---|
| SEC-09 safety (no automation/hidden/background start, fail-closed) | 35 |
| Provenance + consent/setup parity (can we show a physical user start; same dialogs as in-app) | 20 |
| Speed (taps from outside the app) | 15 |
| Implementation + signing risk | 10 |
| Privacy (no content/data leaves or is shared, no new permission/entitlement) | 10 |
| Testability | 10 |

| Option | Safety 35 | Provenance/parity 20 | Speed 15 | Impl/signing 10 | Privacy 10 | Test 10 | **Weighted /5** |
|---|---|---|---|---|---|---|---|
| A navigate-only | 5 | 5 | 2 | 4 | 5 | 4 | **4.35** |
| B start-now everywhere | 2 | 1 | 5 | 2 | 4 | 3 | **2.55** |
| C hybrid | 4 | 3 | 4 | 3 | 5 | 3 | **3.70** |

Scores are engineering judgement from the facts above, not measurements.

## Decision (Proposed): Option A for v1; Option C's Android part is a pre-approved upgrade

**Recommend navigate-only for all six entry points.** Start-now is only worth its risk where the OS
documents a user-tap path *and* consent parity is shared; iOS has neither (provenance not establishable),
and Android's mic-FGS rule for tiles is not documented. The human decides; one-tap vs two-tap below.

### One-tap vs two-tap trade-off (plainly)
- **A (recommended): two taps.** Tap 1 on the widget/control/tile/Action button opens the Record screen;
  tap 2 is the Record button. The second tap is the same tap that today also shows the first-run
  acknowledgement, profile consent and microphone priming, so no path can skip them. It adds roughly
  one second and one touch (on iPhone Action button: press-and-hold, then tap Record). It makes SEC-09
  trivially true: the mic opens only after a tap inside the app, with the app foreground.
- **B/C: one tap** when nothing is pending (acknowledged, mic primed, profile without consent step); two
  or more taps otherwise (dialogs). Faster, but on iOS the system can run the same control from places we
  cannot distinguish (see Provenance), so SEC-09's "no automations" would rest on an assumption.

### Per-entry-point table (recommended = A)
| Entry point | Min OS / hardware | Start-now vs navigate-only | `StartSource` at the moment the mic opens | Visible indicator |
|---|---|---|---|---|
| iOS Home Screen widget | iOS 16 floor works (WidgetKit widget iOS 14.0 [V]; widget extension must deploy at ≥ the app's 16.0) | **navigate-only** (`widgetURL` → Record) | `inAppButton` (the in-app tap) | none at tap time (nothing recording); after the in-app tap: iOS orange mic indicator [V A14] + existing AUD-04 recording indicator |
| iOS Lock Screen widget (accessory family) | iOS 16.0 [V A4] | **navigate-only**; device may be locked: opening the app needs unlock | `inAppButton` | same as above |
| iOS Lock Screen / Control Center control | **iOS 18.0** [V A2]; below iOS 18 not offered | **navigate-only**; control `authenticationPolicy = requiresLocalDeviceAuthentication` [V A12 semantics; device behaviour D8] | `inAppButton` | same as above |
| iOS Action Button | iPhone **with an Action button** ("supported models", list [U D2]); assigned via the **Controls** option [V A13], i.e. the *same control* as above; the **Shortcut** option is deliberately not supported | **navigate-only** | `inAppButton` (see amendments: no new value needed under A) | same as above |
| Android widget | API 26 (RemoteViews AppWidgetProvider; Glance not chosen) | **navigate-only** (PendingIntent → `MainActivity` with the Record route); widget tap is a BAL-exempt launcher interaction [V G6] | `inAppButton` | after the in-app tap: AUD-05 ongoing notification + OS mic indicator |
| Android Quick Settings tile | API 26 (TileService API 24 [V G3]); API 34+ must use the PendingIntent overload [V G3] | **navigate-only** | `inAppButton` | same as above |
| macOS | macOS 13 floor | **in-app only (default, unchanged).** `macosAllowedStartSources = {inAppButton}` (AUD-09); no widget/control/menu-bar starter. WidgetKit has macOS widgets and, from macOS 26, controls [V A2, A4] — not used. | `inAppButton` | macOS menu-bar microphone indicator (ADR-SEC-09 §3, unchanged) |

Existing enum values `homeScreenWidget`, `androidQuickSettingsTile`, `iosControl` stay allowlisted but
**unused** under A (they are the labels for a later start-now upgrade). Android launcher shortcut
(static, API 25 [V G7]) is an optional extra navigate-only entry; QCP-03 may add it, it needs no new
decision.

### Option C upgrade path (not recommended for v1; written so the human can approve it later)
Android widget and tile may become start-now only when (1) D6/D7/D9 pass on Android 14, 15 and 16
devices, (2) the shared start flow (below) exists, and (3) the SEC-09 amendment B below is approved.
iOS Control/Action button/widget stay navigate-only unless Apple documents a provenance signal; if a human
still wants start-now on iOS they must accept amendment B and the risk in "Provenance".

## Invocation provenance
- **iOS: NOT establishable from documentation.** No documented API says whether an App Intent / Control
  invocation came from a physical Action-button press, a Control Center/Lock Screen tap, or a
  Shortcut/automation; `IntentSystemContext` has no such field, and the one documented Action-button
  signal (`preciseTimestamp`) is for Apple Watch Ultra only [V A10]. Making the intent non-discoverable
  (the AUD-08 idea) keeps it out of Shortcuts per A9 [V], but Apple does not document how that interacts
  with the Action button, and a custom URL scheme (`widgetURL`) can be opened by any app or web page, so
  a nonce in a URL proves recency, not a press (the extension cannot share a secret with the app without
  an App Group or keychain group). A "fresh token" therefore does **not** show an automation is
  excluded. **Consequence: every iOS entry point requires an in-app Record tap (Option A).**
- **Android: stronger but not needed for v1.** A widget/tile click is delivered by the launcher/SystemUI
  through a PendingIntent created by our app. If the PendingIntent targets a non-exported trampoline
  activity, no other app can fire it. This is what makes the C upgrade plausible; the claim "only a user
  click fires `TileService.onClick`" is not quoted from docs here → **[U] D9**.

## Consent and setup parity
First-run acknowledgement, profile consent (SEC-07), microphone priming and `consent_confirmed_at`
persistence live in `RecordScreen._record()` (`app/lib/features/recording/presentation/recording_screen.dart`,
lines ~159–230), which calls `RecordingController.start(StartSource.inAppButton)` last; `start()` itself
does none of them (it checks allowlist, state, foreground, call guard). Therefore:
- **Option A:** parity by construction — the quick-capture surface only changes which screen is shown;
  the user then taps the same Record button and the same `_record()` runs. No new code path touches the
  microphone. Setup persistence (`applySetup` after `Ok`) is unchanged.
- **Option B/C (if approved):** QCP-02/03 must first extract `_record()`'s pre-start steps into one shared
  `RecordStartFlow` (ack → profile consent → priming → `controller.start(source)` → `applySetup`
  with `consentConfirmedAt`), used by both the Record button and the hand-off consumer. A cancelled or
  failed dialog ends the flow with no mic access. A source value is passed to `start()` only after the
  flow has completed.

## Single-use hand-off request (all options)
Purpose under A: route the app to the Record screen exactly once per outside tap. Purpose under B/C: the
same, plus permission to run `RecordStartFlow` once.

| Field | Value |
|---|---|
| `id` | random 128-bit (UUIDv4) generated by the issuing side |
| `entry` | enum: `iosWidget`, `iosControl`, `iosActionButton`, `androidWidget`, `androidTile` (routing/labelling only, not a `StartSource`) |
| `mode` | `navigate` (recommended; only value used under A) or `start` (only if B/C approved) |
| `issuedAt` | device-wide monotonic clock (iOS `ProcessInfo.systemUptime`, Android `SystemClock.elapsedRealtime`) |
| `expiresAt` | `issuedAt + **10 seconds**` |
| **Expiry value** | **10 s**: long enough for a Flutter cold start on the oldest supported device (to be measured, D10; if the cold start exceeds 10 s the request is dropped and the user lands on the normal app and taps Record), short enough that a leftover request cannot fire later. |

- **Storage:** none on disk. iOS: carried by the in-app `widgetURL` / the control's intent running in the app
  process, held in a native in-memory singleton, read by Dart through a Pigeon `consumeRequest()`. Android:
  carried as an Intent extra of the explicit PendingIntent into `MainActivity` (non-exported trampoline if C
  is later approved), held in memory. **No App Group, no SharedPreferences/UserDefaults, no keychain, no
  database row, no network.** The widget/control shows static content and reads no app data, so no shared
  container is needed [V A2: buttons are stateless].
- **Consumption:** `consumeRequest()` returns the request and deletes it atomically; a second call returns
  nothing; a request whose `now > expiresAt` is deleted and ignored; the last 16 consumed ids are kept in
  memory to reject replays of the same Intent/URL (e.g. activity recreation).
- **Why this cannot start a recording on app launch:** (1) a normal launch (icon, notification, boot, Dart
  hot start, process restart) has no issuing event, so `consumeRequest()` returns nothing; (2) nothing is
  persisted, so a killed-and-relaunched app has no request; (3) under A the request only selects the Record
  screen and never calls `start()`; (4) under B/C the consumer only runs `RecordStartFlow`, which ends in
  `RecordingController.start(source)`, and that still refuses unless the app is `resumed`, the call guard
  passes, and the phase is idle; (5) unknown/stale/replayed/malformed requests are dropped and logged
  without content (event name + reason only, FND-07). `RecordingController` gets no new entry.

## Widget / control content rule
Static strings and an icon only: the action word ("Record"), the app name, Lumen branding, a fixed SF
Symbol/vector. **No** titles, transcript text, summaries, note counts, last-recording time, profile
names, or recording state on any Lock Screen, Control Center, Home Screen, tile or widget surface. The
extensions read no database or shared container. (If a Live Activity is later added it may show only
"Recording"/"Paused" + timer, as AUD-04's proposal says.) Android tile label is static ("Record"); the tile
state is always `STATE_INACTIVE` and never reflects recording to avoid lock-screen leakage.

## Live Activity (SEC-09 §5 "where supported")
Searched the code today (`ActivityKit|LiveActivity|WidgetKit|AppIntent` over `app/ios`, `app/lib`,
`app/android/app/src`): **no matches; no Live Activity, widget or App Intent exists.** AUD-04 deferred it as
AUD-10 (Live Activity). The OS orange mic indicator [V A14] and the AUD-04 recording indicator are the
visible indicators today. **Proposal:** a Live Activity is **not** a prerequisite for QCP-02 under Option A
(the mic only opens after an in-app tap, where the existing indicators apply). This needs human approval
because SEC-09 §5 says "iOS Live Activity where supported (AUD-04)"; see Question 4. The WidgetKit
extension QCP-02 adds is the same target a later Live Activity would use.

## What each earlier proposal becomes
| Proposal | Fate |
|---|---|
| AUD-11 quick-start entry points (AUD-08 follow-up) | **Absorbed**: QCP-02 (iOS) + QCP-03 (Android). |
| AUD-10 iOS Live Activity (AUD-04 follow-up) | **Stays separate**; not required by this ADR (see above). Renumber when filed: next free audio ID is AUD-10 but it collides, so file as **AUD-13** (AUD-12 is the proposed per-recording destination column). |
| AUD-10 share-extension wiring (AUD-06 follow-up) | **Stays separate**; file as **AUD-14**. Not absorbed: the repo has no wired `ShareExtension` target (only `Runner` and `RunnerTests`; sources exist under `app/ios/ShareExtension/`). QCP-02 adds the *first* extension target (widget/controls) and thereby touches `project.pbxproj`; coordinate merges with AUD-14. |

## No call-related capability is needed
Confirmed against ADR-SEC-09 §2 and the code: the proposed surfaces need **no** call-related permission
(`READ_PHONE_STATE`, `READ_CALL_LOG`, `CAPTURE_AUDIO_OUTPUT`, …), **no** call audio source (only
`mic`/`voiceRecognition` via `RecordingController`), **no** `UIBackgroundModes` change (`audio` stays;
no `voip`), **no** CallKit/PushKit/VoIP entitlement, **no** Accessibility/MediaProjection/overlay. New
manifest/plist items: iOS widget-extension target + `NSExtension` (WidgetKit), custom URL scheme or none;
Android `AppWidgetProvider` receiver, `TileService` with `BIND_QUICK_SETTINGS_TILE` (a bind permission on
our own service; not on the forbidden list), no `FOREGROUND_SERVICE_*` additions under A. The
extensions must contain no microphone code and no `NSMicrophoneUsageDescription`. **Follow-up for
QCP-02:** `tools/ci/check_recording_policy.py` scans Swift sources only under `app/ios/Runner`
(line 133–134), so a new extension directory must be added to its scanned roots (plists/entitlements under
`app/ios` are already scanned).

## Proposed SEC-09 ADR amendments (for human approval; ADR-SEC-09 is not edited by this task)
**Amendment 1 — Option A (recommended). Replace the last two sentences of §4 bullet 1** ("Widget/tile/Control
open the app first; AUD-08 decides whether they start directly or only navigate (the iOS Control must use
`openAppWhenRun`).") **with:**
> "Widgets, Lock Screen/Control Center controls, the Action button (only through the system's *Controls*
> option), the Android widget and the Quick Settings tile are *navigate-only* (ADR-QCP-01): they open the
> app on the Record screen and never call `RecordingController.start`. The recording starts only with the
> in-app Record tap (`StartSource.inAppButton`) after the same first-run acknowledgement, profile consent and
> microphone priming as any in-app start. No App Intent that opens or starts recording is discoverable by
> Siri, Spotlight or Shortcuts, and no Shortcuts action or automation for recording is provided.
> `StartSource.homeScreenWidget`, `.androidQuickSettingsTile` and `.iosControl` remain allowlisted but are
> unused until a later amendment makes an entry point start-now."

**Amendment 2 — only if the human chooses start-now for an iOS Action-button press (not recommended).**
Add `StartSource.iosActionButton` to the enum, `allowedStartSources` and its pinned test, and add to §4:
> "`iosActionButton` — a press-and-hold of the iPhone Action button assigned to VaultVoice's Record
> control through the Action button's *Controls* option. A direct press is an explicit, physical user
> start, like a tap. The Action button's *Shortcut* option and any Shortcuts, Siri, Spotlight,
> Focus/automation, time, location, NFC, CarPlay, Back Tap or other automation trigger are **not** a
> start source: the Record intent is not an App Shortcut and is `isDiscoverable = false`. The app must be
> `resumed` and the shared consent/setup flow runs before `start`. iOS exposes no signal that tells an
> Action-button press from another invocation of the same control (ADR-QCP-01), so this source cannot
> guarantee that automation is excluded."
The final sentence is a deliberate admission: the human must accept that an indirect trigger of the control
cannot be excluded. That is why Amendment 2 is not recommended.

**Amendment 3 — only if start-now is approved for Android widget/tile (Option C).** Append to §4:
> "A start-now entry point may call `RecordingController.start(source)` only (1) after a single-use,
> memory-only request younger than 10 seconds has been consumed, (2) after the shared consent/setup flow
> completed in the foreground activity, (3) with `AppLifecycleState.resumed` verified by the controller, and
> (4) never from `Application.onCreate`, a service, a receiver or a tile callback. A tile or widget tap
> never creates the microphone foreground service itself; the activity creates it while visible
> (AUD-05)."

**Amendment 4 (housekeeping, any option) — §5:** "iOS Live Activity where supported (AUD-04)" is
satisfied, until AUD-13 ships, by the OS microphone indicator plus the AUD-04 recording indicator. (Only if
the human approves Question 4.)

## Risks
- Two taps feel slow; mitigated by landing on the Record screen already set up (profile/destination
  unchanged) and the Action button doing the first tap with a physical press.
- Personal-team signing may block extensions/App Groups on device (D5); no App Group is needed under A, so
  the only signing cost is the extension App ID.
- Control implementation mechanism on iOS 16–25 vs 26+ (`openAppWhenRun` vs `supportedModes`) and the
  "intent in an extension errors" rule [V A7] need a spike inside QCP-02 (D11).
- A custom URL scheme can be opened by anyone: harmless under A (it only shows the Record screen).
- Android PendingIntent/BAL hardening can change per release (G6); re-verify on Android 15/16 devices.

## Consequences
- QCP-02/03 can be sized for navigate-only: widget extension + control (iOS), receiver + tile (Android),
  Pigeon `consumeRequest()`, routing, tests. No change to `RecordingController`, `StartSource` or the
  macOS allowlist.
- If Amendment 2/3 is chosen, add a pinned `allowedStartSources` test and extract `RecordStartFlow`.
- Device rows D1–D11 in `docs/test-plans/device/QCP-01.md` must be run during QCP-02/03; results go in the
  QCP-02/03 plans.

## Questions the human must answer
1. **Approve Option A** (navigate-only everywhere, two taps) and Amendment 1? (Alternative: Option C.)
2. If any start-now entry point is wanted: approve Amendment 3 for Android widget/tile? Approve (against the
   recommendation) Amendment 2 / the new value `iosActionButton` for iOS?
3. Approve that the iPhone Action button is supported **only** through the *Controls* option (no Shortcuts
   action, no discoverable App Intent), and iOS Controls require iOS 18 (iOS 16/17 get widgets only)?
4. Approve that a Live Activity is **not** required before QCP-02 ships (Amendment 4), keeping it as AUD-13?
5. Confirm macOS stays in-app-only.
6. Confirm the 10-second expiry and memory-only storage.
7. Confirm filing AUD-13 (Live Activity) and AUD-14 (ShareExtension wiring) and that QCP-02/03 absorb AUD-11.
