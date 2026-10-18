# App Review / Play review notes (SEC-06)

Paste into App Store Connect → App Review Information → Notes, and Play
Console → App content as applicable. Draft wording; product/legal may edit.

## What the app is
Lumen records audio when the user taps Record, transcribes it on the
device, and writes a Markdown note into a folder the user chooses. No account
is needed and no user content is sent anywhere.

## Recording and calls
- Recording starts only from an in-app tap and always shows an indicator.
- The app never records phone or VoIP calls: it checks the call state before
  starting, stops when a call begins and never resumes by itself.
- No phone-state, call-log, accessibility, screen-capture or CallKit/VoIP
  capabilities are used.
- A first-run explainer and a per-recording confirmation for multi-person
  recordings remind users to get everyone's consent.

## Downloaded models (Guideline 2.5.2 / Play "Device and Network Abuse")
- The speech and language models are **data files** (GGUF / ggml weights).
  They contain no executable code, are never loaded as code, and cannot
  change the app's features or its review-time behaviour.
- The runtimes (whisper.cpp, llama.cpp) are compiled into the app binary
  and reviewed with it.
- The model catalog is signed (Ed25519); every file is checked against its
  SHA-256 before it is installed.
- Models are downloaded only when the user asks. Models can also be
  imported from a file with no network.

## Phase 2 features (SEC-11)
- Ask your notes (behind a feature flag, off by default) answers from the
  user's own notes with the on-device 3B model (a data file from the same
  hosts as the other models). Chat history stays in the encrypted on-device
  database for 30 days; Settings has clear-all and per-chat delete.
- Mind maps are generated on the device and stored in the same database.
- Reminders export writes only the action items the user selects, after an
  explicit tap, to the Reminders app through EventKit. The permission is
  requested on first use. If the user's Reminders sync with iCloud, that is the
  user's own OS setting.
- The Home Screen widget, Control and Quick Settings tile only open the Record
  screen. They show no note content and never start recording by themselves;
  recording still needs the user's tap in the app.
- The Share extension copies an audio file the user shares into the app's
  private App Group inbox for import. It has no network or microphone access.

## Large downloads (Guideline 4.2 / on-demand disclosure)
- Settings and the model screens work without a download. Recording and
  note creation need at least one speech model and one language model.
- Onboarding and Settings → Models show each model's size and the total
  ("Total download: … Wi-Fi recommended"). On mobile data the user is asked
  before the download starts.
- For review: onboarding → Models → download the smallest model, or import a
  sideload file. ⏳ Fill in the smallest model's size, or attach a demo model
  file, before submission.

## Background modes
`audio`: keeps a user-started recording alive. `processing`: runs
transcription of the user's recordings. Neither uses the network.

## Reviewer checklist
- No login, no demo account needed.
- Microphone permission is requested on the first Record tap, after an
  in-app explanation.
