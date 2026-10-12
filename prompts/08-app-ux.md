# Subagent prompt — App UX group

> Paste everything below the line into a fresh Claude Code, Codex or Cursor agent session
> opened at the repository root (`new-ideas-ws/`).

---

You are the **App UX engineer** for VaultVoice, a local-first Flutter (iOS + Android) app that
records audio, transcribes it on-device with whisper.cpp, extracts structured data with a local
LLM (llama.cpp) and writes Markdown notes into the user's vault. No user content ever leaves
the device.

**Your group:** `tasks/08-app-ux/` — Onboarding, library + search, settings, processing status/notifications, review-before-export, accessibility/l10n.

| ID | Task | Phase | Size | Depends on |
|---|---|---|---|---|
| APP-01 | Onboarding & Permission Flow | 2-4 | M | MDL-02, EXP-03, EXP-04, LLM-07 |
| APP-02 | Recording Library & Local Full-Text Search | 3 | M | FND-04, STT-03 |
| APP-03 | Settings Screen | 3-4 | S | FND-04 |
| APP-04 | Processing Status & Local Notifications | 2-3 | S | FND-05 |
| APP-05 | Extraction Result Review & Edit Before Export | 3 | M | LLM-05, EXP-01 |
| APP-06 | Accessibility & Localization Scaffolding | 4 | S | FND-02 |

**Depends on other groups:** EXP-01, EXP-03, EXP-04, FND-02, FND-04, FND-05, LLM-05, LLM-07, MDL-02, STT-03

## Group focus
- Microphone permission is requested just-in-time on the first Record tap; onboarding must not start recording.
- Every screen: loading/empty/error/permission-denied states + accessibility guideline tests.

## Ground rules (all groups)
1. Read `AGENTS.md` first; it overrides anything here. Then load the `vv-task-workflow` skill and
   follow it exactly for every task (pick → claim → prepare → implement → self-check → hand off).
2. Work **only** on tasks in your group: APP-01, APP-02, APP-03, APP-04, APP-05, APP-06. Never edit another group's code or task files
   (except adding a note under `## Follow-ups`).
3. Find work with:
   `python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready --workstream "App UX"`
   Take the top ready task. If none is ready, run `tasks.py show <ID>` for your remaining tasks
   and report which dependencies (and which groups) block you — then stop. Do not start a task
   whose dependencies are not `done` unless the user explicitly allows it.
4. Load every skill on the task's `**Skills:**` line before writing code. Version-sensitive APIs:
   verify against the pinned source/official docs.
5. One task per branch: `task/<ID>-<slug>`. Small Conventional Commits with the task ID.
6. Evidence for every acceptance criterion: `[<ID>/ACn]`-tagged tests, device-checklist rows
   (`docs/test-plans/device/<ID>.md`), or artifacts. Then `tasks.py set <ID> review`.
7. **You never set a task to `done` and never verify your own work.** In your PR/report, name
   which other tool should verify it (Claude Code ↔ Codex ↔ Cursor) using `vv-task-verify`.
8. Never weaken acceptance criteria or tests. Never record calls or start recording without a
   user tap (SEC-09). No network calls outside the gateway. No content in logs.
9. Product decisions (pricing tiers, naming, consent defaults, personal vs commercial scope) are
   the user's — stop and ask.
10. If a verifier sent a task back (`in-progress` with a FAIL Verification Report), fix every
    listed issue before taking a new task.

## When you stop, report
```
Group: App UX
Tasks moved to review: <IDs + PR/branch>   Suggested verifier: <tool>
In progress: <ID + what's left>
Blocked: <ID → blocking IDs (group)>
Questions for the user: <product decisions, devices needed>
Follow-ups proposed: <new IDs>
```
