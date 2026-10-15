# PRF-03 — Built-in Profile: Meeting Action Items

**Workstream:** Profiles | **Phase:** 3 | **Size:** M | **Depends on:** PRF-01, PRF-02, LLM-05, STT-05, PRF-09 | **Source:** §3.1.5
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-benchmark-eval, vv-markdown-vault-export, vv-testing

## Goal
Turn an in-person meeting transcript into attendees, decisions, assigned tasks (checkboxes), and open questions. (Phone/VoIP calls are never recorded — SEC-09.)

## Scope
- [x] Output schema: `title`, `summary`, `attendees[]`, `decisions[]`, `action_items[] {task, owner, due, t}` (`t` = `hh:mm:ss`), `open_questions[]`, `topics[]`.
- [x] Prompt + few-shot examples tuned for small models; owner mapped from diarized/renamed speakers. [~] on-model tuning deferred → PRF-10 (needs 3B-class model + device lab)
- [x] Default Markdown template with YAML front-matter (Obsidian-compatible tags/dates) and `- [ ]` tasks (Obsidian Tasks plugin format).
- [x] This is the **Free tier** "standard meeting summary" (per §7); confirm which fields are Pro-only, if any.

## Acceptance Criteria
- On PRF-09 meeting set: action-item recall ≥ 80%, precision ≥ 80%, owner accuracy ≥ 70% (with diarization).
- Exported note opens cleanly in Obsidian with tasks recognized.

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** fix/prf · **Date:** 2026-10-15
- **Summary:** Built-in `meeting` profile (YAML + `meeting-default` template + 30-case eval set) verified by `builtin_profile_acceptance_test.dart`: schema fields, `- [ ]` Tasks-plugin lines, YAML front-matter, owner mapped from renamed speakers; added `lists.action_items.owner_accuracy: 0.7` target to the eval scoring. Free tier kept (PRODUCT-DECISION in the YAML, LIC-01).
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/PRF-03.md
  - AC2: ✅ test: [PRF-03/AC2]; device: docs/test-plans/device/PRF-03.md
- **Follow-ups:** see below.

## Follow-ups
- Tune prompt/few-shot for ≥ 80 % P/R once a 3B-class model and PRF-10 exist; Real-model eval numbers need a 3B-class model and the device lab (PRF-10); only SmolLM2-135M is available locally and the PRF-09 1B baselines are below target (prompts/examples were not re-tuned — a change would bump the profile version and invalidate golden prompts).
- Confirm in Obsidian that the Tasks plugin recognises the exported tasks (device row).
- LIC-01: confirm meeting stays Free and whether any field is Pro-only.
