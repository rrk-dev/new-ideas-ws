# PRF-03 — Built-in Profile: Meeting Action Items

**Workstream:** Profiles | **Phase:** 3 | **Size:** M | **Depends on:** PRF-01, PRF-02, LLM-05, STT-05, PRF-09 | **Source:** §3.1.5
**Status:** todo
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-benchmark-eval, vv-markdown-vault-export, vv-testing

## Goal
Turn an in-person meeting transcript into attendees, decisions, assigned tasks (checkboxes), and open questions. (Phone/VoIP calls are never recorded — SEC-09.)

## Scope
- [ ] Output schema: `title`, `summary`, `attendees[]`, `decisions[]`, `action_items[] {task, owner, due, t}` (`t` = `hh:mm:ss`), `open_questions[]`, `topics[]`.
- [ ] Prompt + few-shot examples tuned for small models; owner mapped from diarized/renamed speakers.
- [ ] Default Markdown template with YAML front-matter (Obsidian-compatible tags/dates) and `- [ ]` tasks (Obsidian Tasks plugin format).
- [ ] This is the **Free tier** "standard meeting summary" (per §7); confirm which fields are Pro-only, if any.

## Acceptance Criteria
- On PRF-09 meeting set: action-item recall ≥ 80%, precision ≥ 80%, owner accuracy ≥ 70% (with diarization).
- Exported note opens cleanly in Obsidian with tasks recognized.
