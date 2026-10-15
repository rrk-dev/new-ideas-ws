# Beta program (REL-04)

External testing on testers' own devices and vaults, then a hard stop before
production. The tag workflow (`.github/workflows/release.yml`, REL-01) uploads
only to **TestFlight internal** and the **Play internal** track. Promoting
further is the manual `beta` workflow (`.github/workflows/beta.yml`).

Fastlane options below were checked against **fastlane 2.228.0** (pilot
`upload_to_testflight` / `deliver`, supply `upload_to_play_store`). The lanes
were not executed on the authoring machine (no Xcode, no Android SDK).

## One-time console setup

### TestFlight external group

1. App Store Connect → the VaultVoice app → TestFlight → **External Groups** →
   create a group named `VaultVoice External` (override the lane with
   `VV_TESTFLIGHT_EXTERNAL_GROUP` if the name must differ).
2. Add testers by email. External builds need **Beta App Review** the first
   time (and when the beta notes change). The lane sends
   `app/ios/fastlane/beta_review_notes.txt`.
3. Confirm the group is external, not internal. Internal testers are the
   REL-01 upload only.

### Play closed testing

1. Play Console → Testing → **Closed testing**. The Play Developer API calls
   that track `alpha` (fastlane 2.228 default track ids: `internal`, `alpha`,
   `beta`, `production`). Set `VV_PLAY_CLOSED_TRACK` if you created a custom
   closed track id.
2. Create an email list and add testers. They opt in via the Play testing link.
3. The service account in `PLAY_SERVICE_ACCOUNT_JSON` needs permission to
   release to testing tracks (same secret as REL-01).

Do not open the external / closed track until the QA-05 beta-review block in
`docs/parity.md` is signed (Ogg/Opus unsupported on iOS, and the call guard
on one in-lab phone per platform). See the REL-04 follow-up on QA-05.

## Promoting a build

The build must already be on the internal tracks (a finished `release`
workflow run) and, for TestFlight external, finished processing.

GitHub → Actions → **beta** → Run workflow:

| Action | What it runs | Exit criteria |
|---|---|---|
| `external` | `app/ios` `fastlane ios external` (`Fastfile.beta`) | Not required. This is how testers join. |
| `closed` | `app/android` `fastlane android closed` | Not required. Promotes `internal` → closed (`alpha`) for that `build_number`. |
| `production` | `tools/release/beta_gate.py`, then iOS `deliver` and Play promote | **Required.** The gate job fails closed; the store lanes are skipped. |

Inputs: `build_name` (`X.Y.Z`), `build_number` (the release run's number).
`production` also takes `beta_report` (JSON below). The report is counts only.
Do not paste transcripts, notes, audio names, or tester names into it.

Production does **not** ship to the public by itself:

- iOS `deliver` selects the existing build with `submit_for_review: false` and
  `automatic_release: false`. A human submits in App Store Connect after
  REL-05 metadata is real copy, not placeholders.
- Play promotes the closed track to **production** with release status
  `draft`. A human starts the rollout in Play Console.

## In-app feedback

Settings → About → **Send beta feedback**.

The tester writes a message and may set an optional extraction-satisfaction
score from 1 to 5. **Include diagnostics** is off unless they turn it on.
Diagnostics are the FND-07 zip (logs, device info, metrics). The preview
dialog shows the zip before anything is shared. Recordings, transcripts and
notes are not in that zip.

**Share** opens the system share sheet with the subject `VaultVoice beta
feedback`. Mail is one of the destinations the tester can pick; that is the
compose-email path. Nothing is sent until they choose a destination. The app
has no mail server and does not call the network gateway.

<!-- PRODUCT-DECISION: no beta inbox address is compiled into the app.
     Testers pick Mail (or another app) in the share sheet and send to the
     address published with the TestFlight / Play testing instructions.
     Set that address in the testing-group description before external
     testing opens. An empty in-app constant avoids mailing a placeholder. -->

The satisfaction score travels only inside the message the tester shares.
The release manager averages those scores (and any extra survey answers)
into `extraction_satisfaction` on the beta report. The app does not upload
the score.

Logs for this action record the outcome, whether diagnostics were included,
and the message length. They do not record the message text.

## Exit criteria

Production stays blocked until **all** of these are true. Numbers live in
`tools/release/beta_thresholds.json` (the gate and the app evaluator both
read that file's values; tests pin the literals).

| Criterion | Threshold | Where the number comes from |
|---|---|---|
| Beta testers | ≥ **50**, with at least one on iOS **and** one on Android | TestFlight external group + Play closed-testing installers |
| Crash-free sessions | ≥ **99.5%** (`0.995`) | App Store Connect / Play Console (OS-level crash reports, REL-02) |
| Data-loss reports | **0** | Triage (severity S1). A recovered recording that the tester can still export is not data loss; a missing recording or a note that cannot be reconstructed is. |
| Extraction satisfaction | ≥ **0.80** (4/5) | Mean of the optional in-app score and any survey run with the beta |
| Open S1 issues | **0** | Issues labelled `beta` with severity S1 |

<!-- PRODUCT-DECISION: extraction satisfaction target is 0.80 (4 out of 5).
     The task says "≥ target" and does not name the target. 0.80 is the
     bar the gate enforces. Change it only by editing beta_thresholds.json
     and the tests that pin 0.80. -->

### Beta report

```json
{
  "ios_testers": 30,
  "android_testers": 25,
  "crash_free_session_rate": 0.997,
  "data_loss_reports": 0,
  "extraction_satisfaction": 0.86,
  "open_s1": 0
}
```

`ios_testers + android_testers` must be ≥ 50, and neither may be 0.
Rates are fractions from 0 to 1. Counts are non-negative integers.

```bash
python3 tools/release/beta_gate.py report.json
```

Exit 0: criteria met. Exit 1: production blocked (reasons on stderr). Exit 2:
the file is malformed. The script does not print the JSON back.

## Triage

Every piece of beta feedback becomes an issue before it is closed.

1. Label `beta`.
2. Set severity:
   - **S1** — data loss, or a crash that loses a recording or a note. Blocks
     production (`open_s1` must be 0). Fix or explicitly accept with a written
     reason on the issue, then set the count back to 0 only when no S1 is open.
   - **S2** — wrong transcript or extraction the tester can still correct.
     Does not by itself block the gate; do not ship a release that is all S2
     if the satisfaction score is under 0.80.
   - **S3** — layout, wording, confusion. Fix when cheap; does not block.
3. Reproduce on a device from `docs/device-matrix.md` (oldest and newest per
   platform when the report is a crash or data loss). Record the result on
   the issue. Do not attach the tester's audio or transcript; ask them to
   share a diagnostics zip if the log is needed.
4. Link the fixing PR to the issue. When the issue closes, update the next
   beta report's `open_s1` / `data_loss_reports` / satisfaction mean.

S1 from the call-recording policy (the app recorded a call, or resumed after
a call) is a release blocker even if the numeric report would otherwise pass
— file it as S1 so `open_s1` stays above 0 until it is fixed.

## Privacy

- No new network calls. Feedback leaves the device only through the OS share
  sheet.
- Diagnostics stay the FND-07 bundle. The feedback message is not written
  into the zip and is not logged.
- Store crash rates used for the 99.5% bar are the OS consoles' own reports
  (testers opted in with the OS), not an SDK in this app.
