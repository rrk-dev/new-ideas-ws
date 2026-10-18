# GATE-05 — Product Phase 2 scenario: quick capture, templates, Ask, mind maps, Reminders

Task: [GATE-05](../../../tasks/13-milestones/GATE-05-product-phase2.md).
Automated half: `app/integration_test/gate_05_test.dart` (fakes for the microphone, call
guard, model and OS). Device, release-build and human rows:
[../device/GATE-05.md](../device/GATE-05.md), all ⏳. Nothing in this gate has been run on a
device yet.

## Known caveats (read first)

- **Ask quality gates are unmet.** ASK-03 AC1 and the ASK-05 quality targets
  (recall and refusal, 90 % each) were not reached on the 3B model. PRODUCT-DECISION: Ask
  ships behind the setting `ask.enabled`, **off by default**, until the product owner
  decides on the quality question. S3 therefore runs with `ask.enabled` switched on by the
  tester, and a pass of S3 does **not** mean the quality gates pass.
- **Ask is High tier only.** ADR-ASK-02 (human-approved) makes Ask available on devices
  with at least 7 GiB RAM (3B model). Mid and Low devices show "Ask isn't available on
  this device". The task text "3B on Mid and High" is superseded: on Mid and Low the Ask
  check is that screen and that no model is loaded.
- **Live Activity (AUD-13) is a separate task** and is not covered by this gate.
- Several dependencies are in `review`, not `done` (see the task file). The gate is signed
  by a human after they are verified.

## Build under test

The signed release build (`fastlane` release lane; see
[release-checklist.md](../../release-checklist.md)) on the matrix devices in
[device-matrix.md](../../device-matrix.md): High = VV-IOS-16, VV-AND-FLG; Mid = VV-IOS-14,
VV-AND-7; Low = VV-IOS-11, VV-AND-4G. Not a debug build. Use only fictional recordings.

## Steps and expected results

### S1 — Quick capture from each entry (AC1, AC2)

1. For each entry (iOS widget, iOS Control, Android widget, Quick Settings tile, Android
   shortcut) tap it from a locked-and-unlocked device and from a cold start.
2. Check that the app opens on the Record screen and is **not** recording.
3. Tap Record yourself, then stop.
4. Try an expired tap (wait over 10 s before the app opens), a replayed tap, and a
   Shortcuts automation if one can be built.

Expected: no recording ever starts without the in-app Record tap; expired and replayed
taps do nothing; the recording indicator is visible while recording.

Automated: `[GATE-05/AC2]` (every entry navigates only; expired, replayed and malformed
requests are dropped; a call stops a recording and it never auto-resumes).

### S2 — Profiles to a vault note (AC1)

For each of the lecture, sales and interview profiles (TPL-01 to TPL-03): import a short
fictional recording, pick the profile, run the pipeline, and open the note written to the
vault.

Expected: the note has the profile's sections, valid front matter, and opens in Obsidian
or Logseq; the transcript is unchanged.

Automated: the profile and template tests of TPL-01 to TPL-04 in `flutter test`.

### S3 — Ask (AC1, AC3)

1. Seed a library of fictional recordings. Turn `ask.enabled` on (High tier).
2. Ask a question whose answer is in one recording, one spanning two recordings, and one
   that is not in the library.
3. Open each citation.
4. On a Mid or Low device check the "not available" state. On a High device without the 3B
   model check the "Ask requires the 3B model" screen.

Expected: cited answers with recording and timestamp, citations open the passage, refusal
text "I couldn't find that in your notes", the "answers can be wrong" note is visible,
chat history is kept and can be cleared, and no question text is written to logs.

Automated: `[GATE-05/AC3]` (cited answer, refusal, invented citation dropped, Mid/Low
unavailable).

### S4 — Mind map (AC1, AC3)

Open a recording's mind map, expand and collapse nodes, export it as Markdown and as an
image, and open the Markdown in the vault.

Expected: the map matches the note; the export has no active links or HTML; the file
opens in the vault app.

Automated: `[GATE-05/AC3]` (valid tree, inert Markdown export).

### S5 — Reminders (AC1)

Export two action items from a note to Reminders, export them again, then revoke the
permission and export once more.

Expected: two reminders created once; the repeat creates nothing; after revoking, a
message with a Settings action and no change to the note.

Automated: `[GATE-05/AC1]` (created once; revoked permission creates nothing).

### S6 — Stress cases touched by Phase 2 (AC1)

Run D-26 to D-32 from [stress.md](../stress.md) and the earlier cases D-13 to D-17 again
(call handling) on the release build.

Expected: all pass; zero data loss; zero call-capture failures.

Automated: `[GATE-05/AC1]` (every Phase 2 case has a plan entry and a device row).

### S7 — Performance (AC3)

1. Follow the Phase 2 section of [perf.md](../../perf.md): 10 Ask questions on a High
   device with the 3B model, and the mind-map step for a 30 minute recording on one device
   per tier.
2. Compare by hand with `workloads` in `tools/bench/perf/budgets.json` (the report script
   does not evaluate that section).

Expected: Ask cold first answer ≤ 30 s, warm ≤ 20 s, peak RSS ≤ 4200 MiB; mind map ≤ 30 /
60 / 120 s on High / Mid / Low. Otherwise link an ADR-approved revision.

Automated: `[GATE-05/AC3]` (the budgets in `budgets.json` match the task files).

### S8 — Egress on the release build (AC4)

1. Follow [../device/SEC-02.md](../device/SEC-02.md) and the Phase 2 rows of
   [../device/SEC-11.md](../device/SEC-11.md) with a capture proxy: catalog refresh, 3B
   download, an Ask session, a mind map, a Reminders export, a quick-capture entry and a
   Share-extension import.
2. Run `tools/ci/check_egress.sh` on the release commit.

Expected: only hosts from `app/lib/core/network/model_hosts.dart` (plus the documented
redirect host) appear; no integration host.

Automated: `[GATE-05/AC4]` (gateway authorizes only the model hosts and rejects
integration hosts); `check_egress.sh` in CI.

### S9 — Repository check by a human (AC5)

1. On the release commit run
   `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify --all-done --run`.
2. Confirm every GATE-05 dependency is `done`.
3. A human, not an agent, writes the Verification Report.

Expected: exit 0; verifier is a human.

## Pass rule

GATE-05 passes when S1 to S9 pass on the signed release build, with the Ask quality
caveat above either resolved or explicitly accepted by the product owner in the sign-off.
