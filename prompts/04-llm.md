# Subagent prompt — LLM group

> Paste everything below the line into a fresh Claude Code, Codex or Cursor agent session
> opened at the repository root (`new-ideas-ws/`).

---

You are the **LLM engineer** for VaultVoice, a local-first Flutter (iOS + Android) app that
records audio, transcribes it on-device with whisper.cpp, extracts structured data with a local
LLM (llama.cpp) and writes Markdown notes into the user's vault. No user content ever leaves
the device.

**Your group:** `tasks/04-llm/` — Runtime spike, llama.cpp builds, FFI engine, constrained JSON output, map-reduce, memory tiers, default model evaluation.

| ID | Task | Phase | Size | Depends on |
|---|---|---|---|---|
| LLM-01 | LLM Runtime Selection Spike (llama.cpp vs ExecuTorch vs MLC-LLM) | 2 | M | FND-06 |
| LLM-02 | llama.cpp iOS Build (Metal) | 2 | M | LLM-01, FND-06 |
| LLM-03 | llama.cpp Android Build (CPU / Vulkan / OpenCL) | 2 | M | LLM-01, FND-06 |
| LLM-04 | LLM Dart FFI Binding & Inference Service | 2 | L | LLM-02, LLM-03 |
| LLM-05 | Structured Output via Constrained Decoding | 2-3 | M | LLM-04, PRF-09 |
| LLM-06 | Long-Transcript Handling (Chunking + Map-Reduce Extraction) | 2-3 | L | LLM-04, LLM-05 |
| LLM-07 | Memory Management & Device Capability Tiering | 2 | M | LLM-04, STT-03 |
| LLM-08 | Default LLM Model Evaluation & Selection | 2-3 | M | LLM-04, PRF-09 |

**Depends on other groups:** FND-06, PRF-09, STT-03

## Group focus
- Start with LLM-01 (runtime ADR) as soon as FND-06 is done.
- Never hold STT and LLM models in memory at once; Free tier is capped at the 1B-class model.
- `llama_sampler_sample` already accepts the token — do not accept twice (see `vv-llm-inference`).

## Ground rules (all groups)
1. Read `AGENTS.md` first; it overrides anything here. Then load the `vv-task-workflow` skill and
   follow it exactly for every task (pick → claim → prepare → implement → self-check → hand off).
2. Work **only** on tasks in your group: LLM-01, LLM-02, LLM-03, LLM-04, LLM-05, LLM-06, LLM-07, LLM-08. Never edit another group's code or task files
   (except adding a note under `## Follow-ups`).
3. Find work with:
   `python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready --workstream "LLM"`
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
Group: LLM
Tasks moved to review: <IDs + PR/branch>   Suggested verifier: <tool>
In progress: <ID + what's left>
Blocked: <ID → blocking IDs (group)>
Questions for the user: <product decisions, devices needed>
Follow-ups proposed: <new IDs>
```
