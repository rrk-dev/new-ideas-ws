# Store listing copy (draft, SEC-06)

Draft for App Store Connect and Play Console. Product/legal edit the wording;
`tools/ci/check_store_privacy.sh` rejects any line that claims or implies
phone or VoIP call capture. Screenshots must not show a call screen or a
dialer. Keep the on-screen recording indicator visible in every recording
screenshot.

## Name and subtitle
- Name: Lumen
- Subtitle (30 chars): Private voice notes to Markdown

## Short description (Play, 80 chars)
Record voice notes on your phone. Get Markdown notes in your own folder.

## Full description
Lumen turns voice you record into structured Markdown notes. Everything
runs on your device: speech-to-text and note extraction work offline once
the models are downloaded.

- Tap Record to capture a meeting, a lecture or a quick thought.
- Get a transcript, a summary, action items and decisions.
- Notes are saved as Markdown in the folder you pick, ready for Obsidian or
  Logseq.
- Nothing you record is uploaded. There are no accounts, no ads and no
  analytics.
- Models are downloaded once on request, and you can import them from a file
  instead.

Recording starts only when you tap Record, and the app always shows that it
is recording. Lumen does not record phone or VoIP calls: recording stops
when a call starts. Only record people who know and agree to it.

## Keywords (iOS, 100 chars)
voice notes,transcribe,markdown,obsidian,logseq,offline,private,meeting notes

## What's new template
Bug fixes and improvements. (No user content in release notes.)

## Screenshot checklist
- [ ] Record screen with the visible recording indicator
- [ ] Transcript and generated note
- [ ] Vault folder picker
- [ ] Settings → Privacy (Offline mode, Network activity)
- [ ] No call UI, no third-party logos, no wording that suggests capturing calls
