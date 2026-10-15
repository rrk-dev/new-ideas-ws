# GATE-03 — Phase 3 scenario: full pipeline to the vault

Task: [GATE-03](../../../tasks/13-milestones/GATE-03-phase3-notes-in-vault.md).
Automated half: `app/integration_test/gate_03_vault_test.dart` (rendered notes, eval
targets, outbox with a fake vault, consent). Device rows:
[../device/GATE-03.md](../device/GATE-03.md), all ⏳.

Enterprise/MDM (LIC-04) is out of scope for the gates and is not checked here.

## Devices

One iOS device and one Android device with Obsidian installed. On iOS use two vaults:
a local ("On My iPhone") vault and an iCloud vault.

## Steps and expected results

### S1 — Each profile to the vault (AC1)

Repeat for Meeting, Warranty, Engineering and Auto, on iOS (local vault, then iCloud
vault) and on Android:

1. In Settings → Destinations pick the Obsidian vault folder.
2. Select the profile (Auto: leave the profile on Auto) and record about 2 minutes that
   suits it: a meeting with two action items; a warranty details reading (product, serial,
   purchase date, period); an engineering note with a TODO.
3. Stop, wait for the note.
4. Open the note in Obsidian.

Expected: a note appears in the chosen folder; Obsidian shows Properties without a
parse error; tasks (`- [ ]`) render as checkboxes (Meeting action items, Warranty
"Warranty ends" reminder); Auto picks the matching profile or asks when unsure.

Automated: `[GATE-03/AC1]` (front-matter parses, tasks render, eval references exist).

### S2 — Eval targets (AC2)

1. Run `tools/ci/eval.sh --force` (needs the host bridge) with the release-candidate
   models and prompts.
2. Attach the PRF-09 report from `build/eval` to the task Completion Notes.

Expected: Meeting action-item recall and precision ≥ 80 %; Warranty field accuracy
≥ 90 %; Engineering TODO recall ≥ 80 %; schema-valid ≥ 99 % for every profile.

Automated: `[GATE-03/AC2]` checks that the targets in `tools/bench/eval/*/scoring.json`
are at least these values; the measured numbers come from the eval run.

### S3 — Revoke, record, re-grant (AC3)

1. With a vault chosen, revoke access (Android: remove the app from the folder grant in
   system settings; iOS: delete or move the vault folder so the bookmark goes stale).
2. Record and stop. Check the Pending exports list.
3. Re-grant the same folder from the app prompt.

Expected: the note waits in the outbox, then exactly one note is written after re-grant
and the pending list empties. No duplicate files.

Automated: `[GATE-03/AC3]` (revoked → waiting → re-grant → exactly one note).

### S4 — Consent (AC4)

1. Choose the Meeting profile and tap Record.
2. Decline the "Everyone present agrees" dialog: recording must not start.
3. Tap Record again, confirm, record 1 minute, stop.
4. Open the note.

Expected: no recording without the confirmation; the note front-matter has `consent_at`.

Automated: `[GATE-03/AC4]` (consent stored; `consent_at` only when confirmed).

### S5 — Repository check (AC5)

Run `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify --all-done --run` on
`main`. Expected: exit 0; all GATE-03 dependencies `done`.

## Pass rule

GATE-03 passes when S1 passes for all four profiles on every vault and S2 to S5 pass.
