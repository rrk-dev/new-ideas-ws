# Device verification — TSK-02 Export action items to Apple Reminders

The Dart side (selection, idempotency, permission states) is covered by fake-channel unit and
widget tests. The EventKit behaviour in `app/ios/Runner/RemindersHostApiImpl.swift` (shared by the
iOS and macOS Runner targets) is **Unverified** until these rows run on devices. They carry over
and extend the TSK-01 rows D1–D8 in [TSK-01.md](TSK-01.md); the decisions are in
[ADR-TSK-01](../../adr/ADR-TSK-01-task-export.md). D3 is a **release gate**: macOS does not ship
with Reminders export until it passes.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| D1 [TSK-02/AC4] Full access prompt | Fresh install, open Action items, tap Add to Reminders, then Continue | Primer text shows first; Continue raises the system prompt with the usage text; Allow → selection list appears | iPhone | iOS 17+ | ⏳ | | |
| D2 [TSK-02/AC4] iOS 16 / macOS 13 path | Same on the older OS with both plist keys | Prompt appears and the export works. No device: hide the action on that OS and record it | iPhone / Mac | iOS 16, macOS 13 | ⏳ | | |
| D3 [TSK-02/AC4] macOS sandbox entitlement (**release gate**) | Release build with only `com.apple.security.personal-information.calendars` | Prompt appears and items are created; if another entitlement is needed, record its exact name | Mac | macOS 14+ | ⏳ | | |
| D4 [TSK-02/AC4] Items, title, due date and note | Select 3 items (one with `due_iso` date, one with date-time, one with a spoken phrase only), choose the Lumen list, tap Add | Titles equal the item wording; due date set only where `due_iso` existed (time only when given); note reads `Owner: <name>` (when known) and `From Lumen, <date>`; no transcript text | iPhone + Mac | iOS 17+, macOS 14+ | ⏳ | | |
| D5 [TSK-02/AC4] Push twice | Add the same items again; then re-run the Render step and add again | Second push creates nothing (items show Added); no duplicates in Reminders | iPhone + Mac | iOS 17+, macOS 14+ | ⏳ | | |
| D6 [TSK-02/AC4] Deleted reminder | Delete one created reminder in Reminders, reopen the sheet | The item shows "Added earlier, no longer found" and can be added again; no error | iPhone + Mac | iOS 17+, macOS 14+ | ⏳ | | |
| D7 [TSK-02/AC4] Identifier after sync and reinstall | iCloud Reminders on: export, wait for sync, reinstall the app (the link rows are then gone) and export again | Record whether duplicates appear after a reinstall; the data loss case is documented, not a bug | iPhone + second device | iOS 17+ | ⏳ | | |
| D8 [TSK-02/AC4] Dedicated "Lumen" list | Export with the default list choice on iCloud and "On My iPhone" accounts; delete the list; export again; force a creation failure | The list "Lumen" is created and reused; after deletion it is recreated; on failure the default list is used and the notice is shown | iPhone + Mac | iOS 17+, macOS 14+ | ⏳ | | |
| D9 [TSK-02/AC4] Permission denied and revoked | Deny the prompt; later revoke in Settings while the sheet is open | Recovery text and Open Settings button; nothing is created; after re-enabling, the export works | iPhone + Mac | iOS 17+, macOS 14+ | ⏳ | | |
| D10 [TSK-02/AC4] No network from our process | Egress capture (`vv-privacy-security` runbook) while exporting 3 items with iCloud Reminders on | No connection from the Lumen process | iPhone + proxy | iOS 17+ | ⏳ | | |
| D11 [TSK-02/AC4] Android | Open Action items and a recording menu | No Add to Reminders action anywhere | Android phone | API 26+ | ⏳ | | |

## Notes / evidence
Attach screenshots here.
