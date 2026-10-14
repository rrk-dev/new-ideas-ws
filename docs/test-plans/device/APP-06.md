# Device verification — APP-06 Accessibility & Localization Scaffolding

Host evidence: `app/test/widget/accessibility_test.dart` (`[APP-06/AC1]`: every routed screen in
light + dark passes `labeledTapTargetGuideline`, `androidTapTargetGuideline`,
`iOSTapTargetGuideline`, `textContrastGuideline`; every screen renders at 200 % text size without
overflow; tab bar and queue indicator semantics) and `app/test/unit/l10n/hardcoded_strings_test.dart`
(`[APP-06/AC2]`). The screen-reader flow below needs real devices (none available when authored)
and the record → export UI (AUD-08 record screen, APP-05 review, EXP-05 export) — run it once those
land; until then run steps 1–2 and 5–8 on the screens that exist.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [APP-06/AC1] VoiceOver | 1. Settings → Accessibility → VoiceOver on; Display & Text Size → Larger Text max (≈ 200 %+). 2. Launch the dev build; swipe through the tab bar. 3. Record tab: focus the record button, double-tap to start, wait 10 s, double-tap to stop (AUD-08). 4. Wait for "Your note is ready"; open it from the notification; review (APP-05) and export to the vault folder. 5. Library → processing queue indicator → open a recording's status; activate Cancel/Retry. 6. Settings: move through every section; toggle a switch; open a choice dialog and pick an option; open "Open-source & model licenses". 7. Turn on Smart Invert / Increase Contrast and repeat 5–6 visually. 8. Settings → General → Language: set an unsupported language (e.g. Deutsch). | Every control is announced with a meaningful label and its role/state (switch on/off, selected option, record button "Start recording" / "Stop recording, recording 0:10"); progress is read as "<step>, <n> percent"; no unlabeled buttons; the whole record → export flow is completable without sight. At max text size nothing is clipped or overlapping (content scrolls). Status is never conveyed by colour alone. Step 8: app falls back to English. | iPhone (any, iOS 16+) | iOS 16+ | | | |
| [APP-06/AC1] TalkBack | Same steps with TalkBack (Settings → Accessibility → TalkBack) and Display size + Font size at maximum; step 8 via System → Languages. | Same as VoiceOver. | arm64 Android phone | API 26+ | | | |

## Notes / evidence
Screen recordings with screen-reader audio under `docs/test-plans/device/evidence/APP-06/`.
