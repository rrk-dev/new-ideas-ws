# Device verification — SEC-07 Recording Consent

Host evidence: `[SEC-07/AC1]` widget tests in `app/test/widget/record_screen_test.dart`;
`[SEC-07/AC2]` in `app/test/unit/templates/template_note_renderer_test.dart` and
`app/test/unit/recording/recording_session_test.dart`. Decision: `docs/adr/ADR-SEC-07-recording-consent.md`
(Proposed). Leave Result, Date, and Tester blank until run.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-07/AC1] | 1. Fresh install; skip nothing in onboarding. 2. On the consent page, confirm Continue stays disabled until the acknowledgement box is ticked. 3. On Record, choose Meeting (or Auto) and tap Record. 4. Tap Cancel on the dialog. 5. Tap Record again and choose "Everyone present agrees". | 3–4: no microphone indicator, no recording starts. 5: recording starts with the visible indicator. | iPhone 12+ | iOS 17/18 | ⏳ | | |
| [SEC-07/AC1] | Same steps on Android. | Same result; no recording notification appears before step 5. | Pixel 7 | Android 14 | ⏳ | | |
| [SEC-07/AC2] | 1. Record 10 s with Meeting after confirming. 2. Process and export. 3. Open the note in the vault. | Front-matter has `consent_at: "<ISO-8601 with offset>"` near the confirmation time. A personal profile note has no `consent_at`. | Any | iOS 17 / Android 14 | ⏳ | | |
| [SEC-07/AC3] | Product/legal read the explainer, the two dialogs and the never-calls statement. | Wording approved (task stays in review until then). | — | — | ⏳ | | |
