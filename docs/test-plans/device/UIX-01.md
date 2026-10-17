# Device verification — UIX-01 Reference-driven UI refresh

Host tests cover structure, tabs, hidden slots, grouping, accessibility and 2.0× text
(`app/test/widget/library_screen_test.dart`, `modern_ui_scale_test.dart`, `accessibility_test.dart`)
and goldens (`app/test/golden/`). Design judgement needs a person.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [UIX-01/AC5] Design review | 1. Open the supplied reference screenshots next to the Library and Recording detail screens (light and dark, phone and macOS window). 2. Check: grouped rounded cards, round app-bar buttons, tabbed hub, nothing copied from the reference (`docs/design/reference-ui-study.md` "not copied" list), no dead placeholders, no PRO badges. | Structure matches the study; Lumen identity intact; no copied branding, text, icons or colours. | iPhone + macOS build | iOS 16+ / macOS 13+ | ⏳ | | |
