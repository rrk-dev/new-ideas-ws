# ADR-SEC-07 — Recording consent: confirmation default and whether users may turn it off

- **Status:** Proposed (product/legal decision pending)
- **Date:** 2026-10-15
- **Task:** SEC-07
- **Deciders:** product + legal (open); engineering implemented the safest default below
- **Supersedes:** —

## Context
Many users record meetings. Recording laws differ: some places need only the
recorder's consent, others need every participant's. VaultVoice cannot know
the jurisdiction or who is in the room, so it reminds the user instead
(engineering guidance, not legal advice).

## What is implemented now
- First-run explainer (onboarding) with an acknowledgement; the first Record
  tap asks again if it was never given. Recording cannot start without it.
- Profile key `consent_confirmation`:
  - `required` (Meeting, Engineering, and Auto, which may resolve to them):
    a dialog "Everyone present agrees" must be confirmed before the
    microphone opens. Cancel keeps the microphone closed.
  - `optional`: the same dialog, with "Record without confirming" next to
    the default confirm action.
  - `none` (personal notes, Warranty): no per-recording step.
- Confirming stores `recordings.consent_confirmed_at`; the note front-matter
  gets `consent_at` only when it is set. An optional spoken-consent marker
  (`markers.kind = consent`) can be stored at a recording time.
- The confirmation is default **on** and a profile that uses diarization
  cannot use `none` (validator).

## Open decision (Proposed)
Should a user be able to turn the per-recording confirmation off for
multi-person profiles?

| Option | Effect |
|---|---|
| A. No (current): `required` cannot be bypassed; users who do not want the step pick a personal profile | Strongest reminder; some friction for solo meetings |
| B. Yes, in Settings, after a warning: "I will get consent myself" | Less friction; weaker evidence that the user was reminded |
| C. Per-profile: only `optional` profiles may skip (current `optional` behaviour) | Middle ground; profile authors decide |

Recommendation: keep A for built-in multi-person profiles and C for custom
profiles until legal answers. Moving to B needs the legal wording of the
warning and a setting key.

## Consequences
- Wording of the explainer, dialogs and `consentNeverCalls` is a draft; the
  task stays in `review` until product/legal confirm it.
- No audio, transcript text or participant data is stored by the consent
  feature; only a timestamp and an optional marker offset.
