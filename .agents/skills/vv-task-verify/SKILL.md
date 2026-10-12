---
name: vv-task-verify
description: Independently verify a VaultVoice task in status review before it can be done — fresh checkout, re-run all gates and tagged acceptance tests, check device evidence, adversarially try to break it, write the Verification Report, then set done or send it back. Use when asked to verify/review/accept a task.
---

# Independent Task Verification

**Rule:** the agent that implemented a task never marks it `done`. A *different* tool (Codex
verifies Claude Code's work, Cursor verifies Codex's, …) or a human runs this procedure.
`tasks.py set <ID> done` refuses unless everything below is recorded. You are the reviewer the
user trusts — assume the implementation is wrong until you have evidence it is right.

## What the tooling enforces (`tasks.py verify <ID>`)
- Every Scope item ticked `[x]` (or `[~] deferred → <ID>` with reason).
- Every Acceptance Criterion `ACn` (n = position of the bullet under `## Acceptance Criteria`)
  has an evidence line in Completion Notes, marked ✅, of a checkable kind:
  - `test: [<ID>/ACn]` — a test whose name contains that tag exists under `app/`, `packages/`,
    `native/bridge/` or `tools/` (`--run` executes the Dart/pytest ones).
  - `device: docs/test-plans/device/<ID>.md` — a row for `[<ID>/ACn]` with `PASS` and a date.
  - `artifact: <path>` — file exists (ADR, doc, report, benchmark result).
  - `ci: <job/log>` — allowed but *not* machine-checked; you must open it and confirm.
- All dependencies `done`; FND-03 (CI) and QA-01 (test framework) `done` first (bootstrap rule).
- `## Verification Report` with a verifier tool different from the implementer,
  `**Verdict:** PASS` and the verified `**Commit:**` sha.
`tasks.py verify --all-done` runs in CI on every PR, so deleting a tagged test or artifact later
turns that old task red — acceptance tests are permanent regression tests.

## Procedure
1. **Fresh state.** New clone or `git worktree add ../verify-<ID> <branch>`; no reuse of the
   implementer's build dirs or caches. Record the commit sha you verify.
2. **Read** the task file, its Completion Notes, the diff (`git diff main...<branch>`), and the
   skills on the task's `**Skills:**` line — check the code follows them (AGENTS.md rules,
   recording policy, privacy rules, version-pinning).
3. **Gates** (once `app/` exists): `fvm dart format --set-exit-if-changed .`, `fvm flutter
   analyze`, `fvm flutter test --coverage` (+ coverage threshold), native host smoke tests,
   `tools/ci/check_egress.sh`, `tools/ci/check_recording_policy.sh`, `tasks.py validate`.
   Or confirm the PR's CI run is green **for the same sha**.
4. **Acceptance tests:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify <ID> --run`.
   Then read each tagged test: does it actually assert the criterion (numbers, thresholds,
   failure paths), or is it a hollow test? A test that can't fail is a FAIL.
5. **Device evidence:** for every `device:` row, check device/OS/date are plausible and the
   steps match the criterion. If you have the device, re-run at least the riskiest row yourself.
   Missing/blank rows → FAIL (send back, or the human runs them).
6. **Adversarial checks** — try to break it, record what you tried:
   - Edge inputs (empty, huge, unicode, 3 h audio, no space, no permission).
   - Kill/background/rotate/lock mid-operation; airplane mode.
   - For recording code: start during a call, call during recording, background start attempts,
     auto-resume — must all be impossible (SEC-09).
   - For privacy-relevant code: logs at INFO contain no content; no new network hosts.
   - Remove or break the feature locally → the tagged tests must fail (mutation sanity check on
     at least one AC).
7. **Write the report** (append to the task file, template `assets/verification-report.md`).
8. **Decide:**
   - All good → `tasks.py set <ID> done`, commit `chore(<ID>): verified`, push to the PR branch.
   - Problems → `**Verdict:** FAIL`, list issues, `tasks.py set <ID> in-progress`; the
     implementer fixes and returns it to `review`. Never fix the code yourself while verifying
     (it would make you the implementer).

## Rules
- Never weaken an Acceptance Criterion, test, threshold or checklist to get a PASS.
- `**Verifier override:**` (same tool as implementer) only by a named human with a reason.
- A PASS covers exactly the recorded commit; new commits after verification require re-verify.
- Phase gates (GATE-0N tasks) are verified the same way, by a human or a third tool.
