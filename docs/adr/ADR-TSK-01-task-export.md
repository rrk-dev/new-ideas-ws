# ADR-TSK-01 — Action-item export to Apple Reminders (EventKit)

- **Status:** Proposed
- **Date:** 2026-10-17
- **Task:** TSK-01
- **Deciders:** Copilot agent; human reviewer pending
- **Supersedes:** —

## Context
Users want extracted action items in a task app. On 2026-10-17 the user decided: **Apple
Reminders only**. Todoist, Apple Notes and every other service are dropped (out of scope; no
new network host). The promise "no user content ever leaves the device" must hold.

Constraints: iOS 16+ and macOS 13 deployment targets (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`,
`MACOSX_DEPLOYMENT_TARGET = 13.0` in the Xcode projects); Android API 26+; Dart talks to
platform code only through Pigeon (`vv-flutter-architecture`); privacy rules in
`vv-privacy-security`.

## Options
1. **A. EventKit reminders written by a native Pigeon plugin, items chosen by the user in the
   review UI (recommended).** Local, no network code of ours.
2. **B. Share-sheet / URL scheme hand-off.** Not evaluated further: Reminders has no
   documented content-carrying URL scheme we could verify, and it gives no idempotency.
3. **C. Do nothing** (action items stay in the Markdown note and the APP-02 task list).
4. Third-party services (Todoist, Asana, Google Tasks) and Apple Notes: **excluded by user
   decision**, not options.

## Criteria (fixed before evaluating)
| Criterion | Weight |
|---|---|
| Privacy / no new network host or permission | 30% |
| Idempotent, no duplicate reminders | 25% |
| Integration effort and testability | 20% |
| Works on our minimum OS versions | 15% |
| User control (explicit selection) | 10% |

## Evidence
Apple pages were read on 2026-10-17 from the developer.apple.com documentation JSON
(`developer.apple.com/tutorials/data/documentation/...`, the same content the HTML pages
render). Each row is **Verified** (quoted/paraphrased from the page) or **Unverified**
(→ row in `docs/test-plans/device/TSK-01.md`). No device or Xcode build was available.

| # | Claim | Status | Source (developer.apple.com/documentation/…) |
|---|---|---|---|
| E1 | `EKEventStore.requestFullAccessToReminders(completion:)` "prompts people to grant or deny read and write access to reminders". Available iOS 17.0, macOS 14.0 (also iPadOS/Mac Catalyst 17.0). | Verified | `eventkit/ekeventstore/requestfullaccesstoreminders(completion:)` |
| E2 | **There is no write-only access level for reminders.** The write-only API is events-only (`requestWriteOnlyAccessToEvents(completion:)`, iOS 17 / macOS 14, "can create events, but can't access any existing calendars and events … including events your app created"). The access-request topic list of `EKEventStore` has only `requestFullAccessToReminders` for reminders. Consequence: creating reminders needs **full read/write** access to all of the user's reminders. | Verified (absence read from the documented API list; recorded as such) | `eventkit/ekeventstore/requestwriteonlyaccesstoevents(completion:)`, `eventkit/ekeventstore` |
| E3 | `requestAccess(to:completion:)` is deprecated at iOS 17 / macOS 14 ("Use … requestFullAccessToRemindersWithCompletion:"). It is the only call on iOS 16 / macOS 13, our minimums. | Verified deprecation; **Unverified** that it still prompts and works on an iOS 16 / macOS 13 device | `eventkit/ekeventstore/requestaccess(to:completion:)` |
| E4 | Info.plist: `NSRemindersFullAccessUsageDescription` (iOS 17.0+, macOS 14.0+) "tells people why the app is requesting access to read and write their reminders data" and "is required if your app uses APIs that access the person's reminder data". `NSRemindersUsageDescription` is the legacy key, deprecated iOS 17 / macOS 14. | Verified | `bundleresources/information-property-list/nsremindersfullaccessusagedescription`, `…/nsremindersusagedescription` |
| E5 | Whether iOS 16 / macOS 13 read the new key or still need the legacy key. | **Unverified** → ship **both** keys with the same text (legacy key is needed on < 17 by definition of its deprecation, not removal), device row D2 | — |
| E6 | `EKCalendarItem.calendarItemIdentifier` "is set when the calendar item is created and can be used as a local identifier. Use `calendarItem(withIdentifier:)` to look up the item by this value. **A full sync with the calendar will lose this identifier.** You should have a plan for dealing with … an identifier [that] is no longer fetch-able by caching its other properties." Both APIs available iOS 6+/macOS 10.8+. | Verified | `eventkit/ekcalendaritem/calendaritemidentifier`, `eventkit/ekeventstore/calendaritem(withidentifier:)` ("locates a reminder or the first occurrence of an event with the specified identifier, or nil") |
| E7 | `calendarItemExternalIdentifier` is server-provided, works across devices, can be duplicated, and for Exchange "is different between iOS and macOS and different between devices for reminders". → **not** used as our key. | Verified | `eventkit/ekcalendaritem/calendaritemexternalidentifier` |
| E8 | **Read back by id: yes**, via `calendarItem(withIdentifier:)` (E6), as long as the identifier survives (not lost by a full sync; the user did not delete the reminder). Whether it is stable across an iCloud-sync round trip on the same device in practice, and across app reinstall. | API verified; **real-world stability Unverified** → device rows D4, D5 | as E6 |
| E9 | macOS App Sandbox: the entitlement `com.apple.security.personal-information.calendars` ("read-write access to the user's calendar", macOS 10.7+) is added in Xcode under App Sandbox → Calendar. The page does not mention reminders. | Entitlement exists: Verified. **That it also governs Reminders: Unverified** → device row D3. | `bundleresources/entitlements/com.apple.security.personal-information.calendars` |
| E10 | EventKit is an OS framework that talks to the local reminders database (`EKEventStore`); sync is the Reminders/iCloud account's own OS behaviour. | The page text states only the local API; "no network call from our process" is **Unverified** by capture → device row D6 (egress capture) | `eventkit/ekeventstore` |

What we already ship: `app/macos/Runner/Release.entitlements` has App Sandbox,
`device.audio-input`, `files.user-selected.read-write`, bookmarks and
`network.client` (existing; the model downloader uses it). Neither iOS nor macOS currently
has a Reminders/Calendars key or entitlement.

## Decision
We choose **Option A**, as a **Proposed** design with the following parts.

### 1. Privacy position
The destination is the on-device Apple Reminders store through EventKit. If the user's
Reminders list lives in iCloud (or Exchange), syncing is the user's own OS account setting,
done by the OS, outside our client; we state this in the UI and in the privacy audit. **No
network code, no new host, no allowlist change** (`kModelHosts` untouched). No third-party
service, SDK or package: the plugin is our own Swift code behind Pigeon
(`vv-ffi-bridge`/`vv-flutter-architecture` rule: no third-party native Dart packages without an
ADR). Reminder content is never logged (`vv-privacy-security`: ids only, hashed).

### 2. Permission and entitlement amendments (the confirmation the task demands)
Needed, and **nothing else**:
- iOS and macOS `Info.plist`: `NSRemindersFullAccessUsageDescription` and (for the iOS 16 /
  macOS 13 minimums, E3/E5) `NSRemindersUsageDescription`, same user-facing text: "VaultVoice
  adds the action items you choose to your Reminders. They stay on your device; if your
  Reminders sync with iCloud, that is your own iCloud setting."
- macOS entitlement `com.apple.security.personal-information.calendars` (E9; confirm on
  device that it is the right one for reminders, D3).
- No new network host, no `network` entitlement change, no Android permission.

This is a user-visible permission (full read/write of all reminders, E2), which is wider than
the feature needs. It is requested **only on the first tap of "Add to Reminders"**, never at
launch. This is outside what `AGENTS.md` lists as allowed ("permission beyond the Reminders
usage description"): it is exactly the Reminders usage description, so no stop is required,
but the human reviewer must approve the entitlement line and the E2 wording before the
implementing task (TSK-02, to be created) starts.

### 3. Platform positions
- **iOS 17+:** `requestFullAccessToReminders`. **iOS 16:** the deprecated
  `requestAccess(to: .reminder)` — implement behind an availability check; device row D2. If
  D2 fails, the fallback is to hide the feature on iOS 16 (the Markdown note is unaffected).
- **macOS:** supported, **same plugin and rules**, macOS 14 API with the macOS 13 fallback
  (E3). Requires the sandbox entitlement (E9/D3). The macOS build is currently a
  developer/test target (`app/macos`); if the product ships it, the feature ships with it,
  otherwise it is simply unreachable there. Not a store gate.
- **Android: no Apple Reminders; Android users get nothing from this task.** The button is not
  shown (`Platform` capability check, not an error). Their action items remain in the Markdown
  note (EXP-01) and the in-app task list (APP-02). Any Android task integration (e.g. Google
  Tasks) is out of scope by the user's decision.

### 4. Shared domain model (`ExportableActionItem`)
Source: table `action_items` (`app/lib/core/db/tables/extraction_tables.dart`: `id` auto-inc,
`recordingId`, `extractionId`, `body`, `owner?`, `dueIso?`, `tMs?`, `done`, `doneAt?`).

**Eligibility** — a row is offered iff **all** hold:
1. `done == false`;
2. `body.trim()` is non-empty;
3. the recording and extraction still exist (FK cascade guarantees this);
4. it is not already exported (§5: an export link exists and resolves).

**Mapping to `EKReminder`:**
| Reminder field | Value |
|---|---|
| `title` | `body.trim()`, whitespace-collapsed, truncated to 255 characters at a grapheme boundary (limit is **our** choice, not an Apple fact) |
| `notes` | `Owner: <owner>` only if `owner` non-empty (text, never resolved to a contact, never assigned); then `From VaultVoice, <recording date>`. **No transcript text, no source `t`, no recording title/filename** (content-minimal). |
| `dueDateComponents` | only when `dueIso` is non-null **and** parses as a strict ISO-8601 calendar date or date-time; date-only → `year/month/day` components (no time, no alert); date-time → plus hour/minute. Unparseable → no due date. **Never inferred from spoken text** ("next Friday"). |
| `calendar` | the user's chosen Reminders list (default `defaultCalendarForNewReminders()`); remembered in settings as its calendar identifier, falling back to the default if it is gone |
| `priority`, alarms, URL, location, recurrence, assignee | not set |

`owner`, `body` are untrusted strings from the LLM (T5): they are passed as data to
EventKit only, never interpolated into any URL or command.

### 5. User selection
Reuse the APP-05 review/selection UI: the review screen (`/library/recordings/:id/review`)
gains an "Add to Reminders" action; the APP-02 task list (`action_items_screen.dart`,
`CheckboxListTile` rows) is the second entry point. Nothing is exported without an explicit
tap and an item selection screen showing exactly the title, owner text and due date that will
be written. **There is no automatic export** after a recording or in the pipeline
(no `PipelineStep`; the worker isolate never touches EventKit).

### 6. Stable export identity (idempotency)
`action_items.id` cannot be the key: `RenderStep` calls `replaceActionItems`, which deletes all
rows of the extraction and re-inserts them (new ids) on every re-render, and a
re-extraction creates a new `extractionId`. Edits made in the APP-05 review change `body`.

Definition (all computed in Dart, pure functions, unit-testable):
```
norm(body)   = NFKC → lowercase → trim → collapse whitespace runs to one space
               → strip leading/trailing punctuation [.,;:!?-–—"'] 
itemKey      = sha256( recordingId ␟ norm(body) ␟ occurrence )   (hex, ␟ = U+001F)
occurrence   = 0-based count of earlier items of the SAME recording with the same norm(body)
               (ordered by tMs ascending, nulls last, then body) 
```
`extractionId`, `id`, `owner`, `dueIso`, `tMs` are **not** in the key, so the identity
survives re-render and re-extraction that yields the same task wording; a changed owner or
due date does not create a duplicate.

Persistence (new table `reminder_exports`, a drift migration, created by the implementing
task — **not** in this docs task): `item_key` (PK), `recording_id` (FK cascade),
`calendar_item_id` (EventKit `calendarItemIdentifier`), `reminder_calendar_id`,
`exported_at`, `body_norm_at_export`. Encrypted DB (SEC-01), no body text stored beyond what
`action_items` already holds (`body_norm_at_export` may be dropped if the hash is enough).
Deleting the recording cascades the link; the reminder itself is **never** deleted by us.

Reconciliation, evaluated at selection time (never in the background):
| Situation | Behaviour |
|---|---|
| Key has a link and `calendarItem(withIdentifier:)` returns a reminder | Shown as "Added" (greyed, not selectable). **Never updated or overwritten** (the user may have edited, completed or moved it in Reminders). |
| Key has a link but lookup returns nil (user deleted it, or a full sync lost the id, E6) | Shown as "Added earlier – no longer found". Selectable to re-add, which replaces the link. Never re-created silently. |
| Re-render, same wording | Same key → still "Added". No duplicate. |
| User edited the wording in review, or re-extraction phrased it differently | Different key → treated as a **new** item; the old link stays orphaned (kept until the recording is deleted). Accepted limitation, stated in the UI ("changed items can be added again"). Fuzzy matching is rejected: a wrong match would hide a real task. |
| Two identical bodies in one recording | `occurrence` index distinguishes them; reorder across re-extraction can swap which is "added" — harmless. |
| Item marked `done` after export | No sync back (one-way, create-only). |

### 7. Failure handling
**No EXP-06 outbox.** The export is an immediate user-initiated action on the foreground
isolate; a retry queue would write reminders later without the user present. Rules:
- Save each reminder with `save(_:commit:)` in one batch and `commit()` once; per-item
  result (`ok / failed`). Link rows are written only after a successful commit.
- Access denied/restricted (`EKAuthorizationStatus`) → a `Failure` mapped to a localized
  message with an "Open Settings" action; nothing is queued.
- Partial failure → the failed items remain selectable; successfully committed ones are
  linked, so a second tap never duplicates them (idempotent by §6). If the process dies
  between commit and link-write, the next attempt can duplicate that batch: accepted (small
  window); mitigation: write links immediately after commit and put the key into nothing
  user-visible. (An optional marker in `notes` would allow recovery but adds an identifier to
  user data; rejected for now.)
- `EKEventStoreChangedNotification` while the sheet is open → refresh the "Added" state.

### 8. Free vs Pro — PRODUCT-DECISION (for LIC-05; not decided here)
`PRODUCT-DECISION: placement of "Add to Reminders" in Free vs Pro.` Options:
(a) Free, as it is local and cheap; (b) Pro, as a convenience/integration feature;
(c) Free for N exports, Pro unlimited. Today **no Pro tier is enforced — everything is
unlocked** (LIC-05's switch is off), so the implementation must gate through the
entitlements service/`Feature` enum like any other feature (`vv-licensing-iap`: never an
inline `if (pro)`), declare the intended tier as provisional, and ship unlocked. The decision
belongs to the user; LIC-05 records it.

## Consequences
- Positive: no new host, SDK, or server; the promise holds; idempotent; explicit user control;
  Android and macOS positions are clear.
- Negative / risks:
  - Full read/write Reminders permission is the only level (E2) – broader than needed.
    Mitigation: request on first use only, explain in the prompt text, never read reminders
    other than our linked ids.
  - iOS 16 / macOS 13 path relies on a deprecated API (E3/E5) – device rows D1/D2.
  - Identifier loss after a full sync (E6) → "no longer found" handling.
  - Duplicates after a reworded re-extraction (accepted).
  - iCloud sync of exported reminders is outside our control (E10); users must be told.
- Follow-up tasks (to be created by the human/lead): TSK-02 implementation (Pigeon plugin,
  `reminder_exports` migration, UI, tests tagged `[TSK-02/ACn]`, final plist/entitlement
  change after approval); SEC-11 final privacy/threat updates; LIC-05 tier.

## Open product questions
1. Free vs Pro (§8).
2. Approve the full-access permission wording and the macOS entitlement (§2)?
3. Is macOS a shipped target, or only a development host?
4. Default list: system default, or a dedicated "VaultVoice" list created by us (creating a
   list needs `saveCalendar`; not verified/decided)?
