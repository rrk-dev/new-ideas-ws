# Reference UI study (UIX-01)

Patterns observed in a third-party mobile voice-notes app, used as **inspiration for structure
only**. Lumen keeps its own identity (tokens in `app/lib/core/theme/app_tokens.dart`, teal accent,
`LumenCard`, `SectionHeader`).

## Supplied material (the only source)
Seven user-supplied screenshots (kept outside the repo; not copied here) of the reference app:
1. Ask screen (chat) 2. Live transcript 3. Language picker 4. Summary-theme picker
5. Mind map 6. Transcript with speaker names (a low-resolution thumbnail) 7. Recording detail
header/app bar. Nothing else about the reference app was inspected; no detail beyond these
screens is assumed.

## What each screen contains
| # | Screen | Content and structure |
|---|---|---|
| 1 | Ask | Chat layout: user question in a soft rounded bubble, bulleted answer, history button (top-left), new-chat button (top-right), large rounded input pill with a circular send arrow; pastel gradient background. |
| 2 | Live transcript | Timestamped lines separated by dashed hairlines, speaker avatars; bottom bar with a waveform icon, a timer and a red finish button. |
| 3 | Language picker | Grouped rounded cards of radio rows, grey captions. |
| 4 | Summary theme picker | "Create new" row, then grouped radio rows (an auto-detect default, several note styles); some rows carry plan badges. |
| 5 | Mind map | Pan/zoom dotted-grid canvas, root node left, colour-coded pill branches fanning right, overflow menu. |
| 6 | Transcript | Coloured speaker names and a "tag participant" action. |
| 7 | Detail app bar | Round icon buttons (back, share, list, more). |

## Adopted (as patterns, in Lumen's own look)
- **Grouped rounded cards with hairline dividers** for lists (`GroupedCard`): Library rows, extracted
  fields, exports, action items.
- **Date sections** in the Library (Today / Yesterday / Earlier this week / Earlier).
- **Circular tonal icon buttons** in app bars (`CircleIconButton`, `circleMenuStyle`).
- **Sectioned recording hub** (tabs): Summary, Transcript, Action items, plus hidden slots for
  Mind map (MAP-02) and Ask (ASK-04) via `recordingHubSlotsProvider`.
- Radio-row pickers and chat layout language are noted for the template picker / Ask tasks; they are
  not built here (features do not exist yet).
- Pastel accent colour-coding: reserved for the Mind map/speaker tasks, using Lumen tokens.

## Deliberately not copied (explicit list)
- Name, logo, branding, tone and **all copy text** (every string is Lumen's own, in ARB).
- Their icons, illustration, fonts, colours (gradient, red button, pastel palette) and any asset.
- Plan/"PRO" badges: Lumen has no paid tier for now; nothing is gated.
- Any wording or feature implying phone-call recording (SEC-09): no "call summary" or similar.
- Placeholder tabs or buttons for unbuilt features (Ask, Mind map, template picker, language picker).
- Their avatars and "tag participant" (Lumen does not use voiceprints or identities).
- The live-transcript screen and its bottom bar: the Record screen is unchanged (see Follow-ups).

## Layout notes (mockup descriptions)
Phone = 390 dp wide; wide = macOS window, content centred and capped at
`AppSizes.maxContentWidth` (640 dp). Light and dark use the same layout; only theme tokens differ.

### Library list
- App bar: title "Library"; right: two round tonal buttons (Action items, Sort).
- Search field, then horizontally scrolling filter chips (Status, Profile, Tag, Date, Clear).
- Body: for Newest/Oldest sort, one section header + one rounded card per date group, rows
  separated by hairlines (icon, title, facts, status/export, search snippet). For Longest/Title
  sort, one ungrouped card.
- Empty state: centred icon + existing message ("No recordings yet…"); no-match state likewise.
- Wide: list column centred at 640 dp.

### Recording detail hub
- App bar: back, title, round "more" menu (review, extract again, change profile, export again, delete).
- Under it: facts line (date · duration · profile), tag chips, review banner when waiting for review.
- Tab bar (scrollable, start-aligned so it survives 2× text): **Summary** (processing status card,
  extracted fields card, exports card), **Transcript** (first lines + "Show the full transcript"),
  **Action items** (rows from the extraction's `action_items`). Mind map / Ask: appear as extra
  tabs only when a feature registers a `RecordingHubSlot`; none today.
- Wide: hub centred at 640 dp.

### Record screen entry (QCP-02/QCP-03)
Unchanged in this task. Quick-capture entry points open the existing Record screen, where the
explicit tap, indicator and consent flow stay as they are (SEC-09). A future restyle of the
live bar (waveform + timer + Finish) is proposed as a follow-up.
