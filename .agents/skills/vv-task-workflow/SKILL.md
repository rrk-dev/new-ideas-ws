---
name: vv-task-workflow
description: "Start here for any VaultVoice task in tasks/ (IDs like FND-01, STT-04). Pick an unblocked task, claim it, load its listed skills, implement in scope, verify every acceptance criterion, close with evidence. Use for \"work on/pick up/finish a task\"."
---

# VaultVoice Task Workflow

Three different agents (Claude Code, Codex, Cursor) work on this repo. This procedure keeps their
work consistent and prevents two agents from doing the same task.

## Task file anatomy
Each task in `tasks/<NN-workstream>/<ID>-<slug>.md` has:
- Line 3 metadata: `**Workstream:** … | **Phase:** … | **Size:** … | **Depends on:** IDs | **Source:** …`
- `**Status:**` line — `todo` → `in-progress` (implementer) → `review` (implementer hand-off) →
  `done` (independent verifier only); `blocked` any time; FAIL in verification → `in-progress`
- `**Skills:**` line — skills you MUST load before coding
- `## Goal`, `## Scope` (checkboxes), `## Acceptance Criteria`, optional `## Notes`
- You add `## Completion Notes` (and `## Follow-ups` if needed) when finishing; the verifier adds
  `## Verification Report`.

## Procedure

### 1. Pick
`ready` runs `git fetch --prune` first so claims pushed by other agents are visible
(`--no-fetch` to skip). Windows: `py -3` instead of `python3`.
```bash
python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready          # unblocked todo tasks
python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready --phase 1
python3 .agents/skills/vv-task-workflow/scripts/tasks.py show FND-04    # deps + status
python3 .agents/skills/vv-task-workflow/scripts/tasks.py validate       # lint all task files
python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-04  # what the verifier gate will check
```
**Bootstrap first:** FND-01 → FND-02 → FND-03 (CI) → QA-01 (test framework), plus QA-05. No
other task can reach `done` until FND-03 and QA-01 are done, so pick those first.
Run `tools/setup/doctor.sh` before your first task; if the core toolchain is missing, stop and ask
the user (never install system tools without approval).
`ready` also lists **[provisional]** tasks: their deps are in `review` with only physical-device
runs pending. You may start those; they cannot become `done` before their deps.
A task is *ready* when its status is `todo` and every `Depends on` task is `done`, and no
`task/<ID>-*` branch exists locally or on the remote (someone else claimed it).
If the user named a task, use it — but if dependencies are not `done`, tell the user which ones
and ask before proceeding (some deps are soft, e.g. a fake implementation may suffice).

### 2. Claim
```bash
git switch -c task/<ID>-<slug>
python3 .agents/skills/vv-task-workflow/scripts/tasks.py set <ID> in-progress
git commit -am "chore(<ID>): claim task" && git push -u origin HEAD   # push = visible claim
```
If you cannot push (no remote/permission), tell the user the claim is local only.

### 3. Prepare
- Read the whole task file, its dependencies' Completion Notes, and any ADRs they produced.
- Load every skill on the `**Skills:**` line. Always also follow `AGENTS.md` rules.
- If the task is a decision/spike (title says "decision", "spike", "evaluation", or Scope says
  "Record decision"), follow `vv-decision-records` and produce the ADR first.
- Turn Scope checkboxes into your plan. Anything ambiguous: check the master plan section named
  in `Source:`; if still ambiguous, ask the user rather than guess on product decisions
  (pricing tiers, which features are Pro, naming). Engineering choices: decide and write an ADR.

### 4. Implement
- Small commits: `feat(<ID>): …`, `test(<ID>): …`, `docs(<ID>): …`.
- Tick Scope checkboxes in the task file as items land (`- [x]`).
- Tests are part of the task, not a follow-up (see `vv-testing`).
- Version-sensitive APIs: verify against pinned headers / official docs; note the version.
- If you discover work outside scope: append it to `## Follow-ups` with a proposed task ID
  (next free number in that workstream) — do not implement it.

### 5. Self-check (Definition of Done for the implementer)
All must be true before hand-off:
- [ ] Every Scope checkbox is `[x]` or explicitly `[~] deferred → <follow-up ID>` with reason.
- [ ] **Every Acceptance Criterion has checkable evidence** (ACn = n-th bullet under
      `## Acceptance Criteria`):
  - Automatable criterion ⇒ a test whose name contains the tag `[<ID>/ACn]`
    (e.g. `test('[FND-05/AC1] resumes after kill', …)`) — see `vv-testing` → Acceptance tags.
  - Device-only criterion ⇒ a row in `docs/test-plans/device/<ID>.md`
    (template `vv-task-verify/assets/device-checklist.md`) with exact steps + expected result.
    Fill Result/Date only if you actually ran it on that device.
  - Document/decision criterion ⇒ the artifact path (ADR, doc, benchmark report).
- [ ] Gates pass locally (once `app/` exists): `fvm dart format --set-exit-if-changed .`,
      `fvm flutter analyze`, `fvm flutter test`; native smoke tests for native changes;
      `tools/ci/check_egress.sh`, `tools/ci/check_recording_policy.sh`.
- [ ] No new network calls outside the gateway; no content logged (`vv-privacy-security`).
- [ ] Docs/ADRs the task requires are committed and linked.

### 6. Hand off for independent verification
Append to the task file (the evidence lines are machine-checked — keep the format exactly):
```markdown
## Completion Notes
- **Agent:** <Claude Code | Codex | Cursor> · **Branch:** task/<ID>-… · **Date:** YYYY-MM-DD
- **Summary:** what was built, key files.
- **Acceptance evidence:**
  - AC1: ✅ test: [<ID>/AC1]
  - AC2: ⏳ device: docs/test-plans/device/<ID>.md
  - AC3: ✅ artifact: docs/adr/ADR-<ID>-<slug>.md
- **Decisions:** ADR-<TASK-ID>-… (if any)
- **Follow-ups:** <IDs or none>
```
(`✅` done, `⏳` pending a device run, `❌` failed; several evidence items: separate with `;`.)
Then `python3 .agents/skills/vv-task-workflow/scripts/tasks.py set <ID> review` — it refuses if
any criterion lacks evidence or any Scope item is open. Commit, push, open the PR titled
`[<ID>] <title>` and say which tool should verify it.

**You never set `done`.** A different tool or a human runs `vv-task-verify`, writes the
Verification Report and sets `done` (the script enforces a different verifier). Only a human
merges the PR.

## Status rules
- `blocked`: add `**Blocked by:** <reason / ID>` under the Status line.
- Never edit another in-progress task's file except to add a note under `## Follow-ups`.
- Never change a task's Acceptance Criteria to make it pass. Propose changes to the user.

## Adding a new task
Copy `assets/task-template.md`, use the next free ID in the workstream, add it to the workstream
table in `tasks/README.md`, then run `tasks.py validate`.
