# Device verification — TSK-01 Action-item export decision: Apple Reminders

TSK-01 is a docs-only decision task (no code). These rows verify the **Unverified** claims in
[ADR-TSK-01](../../adr/ADR-TSK-01-task-export.md) with a throw-away spike
(`tools/spikes/TSK-01-reminders/`, to be written by the verifier or by TSK-02), because no
iPhone/Mac or Xcode run was available when the ADR was authored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| D1 [TSK-01/AC1] Full access prompt, iOS 17+ | Spike calls `requestFullAccessToReminders`, then saves one reminder | Prompt shows the usage text; granted → reminder appears in Reminders; denied → status `denied`, no crash | iPhone | iOS 17+ | ⏳ | | |
| D2 [TSK-01/AC1] iOS 16 / macOS 13 path (ADR E3, E5) | Same with `requestAccess(to: .reminder)`, with (a) both plist keys, (b) only the new key | Prompt appears and save works with both keys; record whether the new key alone is enough. If no iOS 16 device: mark N/A and decide to hide the feature on iOS 16 | iPhone / Mac | iOS 16, macOS 13 | ⏳ | | |
| D3 [TSK-01/AC1] macOS sandbox entitlement (E9) — **release gate: must PASS before macOS ships** | Sandboxed spike with only `com.apple.security.personal-information.calendars` | Reminders access works (or: another entitlement is needed → report exact name) | Mac | macOS 14+ | ⏳ | | |
| D4 [TSK-01/AC2] Read back by id (E6, E8) | Save, store `calendarItemIdentifier`, relaunch the app, call `calendarItem(withIdentifier:)`; then edit the title in Reminders and repeat | Returns the same reminder with the edited title; deleted reminder → nil | iPhone / Mac | iOS 17+, macOS 14+ | ⏳ | | |
| D5 [TSK-01/AC2] Identifier after sync and reinstall (E6, E8) | iCloud Reminders on: save, wait for sync, toggle Reminders iCloud off/on or sign a second device in, reinstall the app, look up the stored id | Record whether the id still resolves; if not, "no longer found" UX applies | iPhone + second device | iOS 17+ | ⏳ | | |
| D6 [TSK-01/AC1] No network from our process (E10) | Proxy/egress capture (`vv-privacy-security` runbook) while exporting 3 items with iCloud Reminders on | No connection from the Lumen process | iPhone + proxy | iOS 17+ | ⏳ | | |
| D7 [TSK-01/AC3] Due date mapping | Export items with date-only and date-time `due_iso` | Reminder shows the due date (and time only when given); no alert | iPhone | iOS 17+ | ⏳ | | |
| D8 [TSK-01/AC3] Dedicated "Lumen" list (ADR §4, human decision) | Create the "Lumen" list with `saveCalendar` on the default Reminders source (iCloud and "On My iPhone"), export 2 items into it, delete the list, export again; also force a failure (no writable source) | List is created and used; after deletion it is recreated; on creation failure the items go to the default list with a notice | iPhone + Mac | iOS 17+, macOS 14+ | iPhone | iOS 17+ | ⏳ | | |

## Notes / evidence
Attach screenshots and the spike output here.
