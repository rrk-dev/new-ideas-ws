# PRF-05 — Built-in Profile: Engineering / Brainstorming

**Workstream:** Profiles | **Phase:** 3 | **Size:** S | **Depends on:** PRF-01, PRF-02, LLM-05, PRF-09 | **Source:** §3.1.5
**Status:** in-progress
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-benchmark-eval, vv-markdown-vault-export, vv-testing

## Goal
Extract architectural concepts, API designs, trade-offs, and immediate TODOs from technical discussions.

## Scope
- [ ] Schema: `title`, `context`, `concepts[]`, `api_designs[] {name, description, endpoints_or_signatures}`, `tradeoffs[] {option, pros, cons}`, `decisions[]`, `todos[]`, `open_questions[]`.
- [ ] Technical vocabulary hints for STT (initial prompt) configurable by the user.
- [ ] Template rendering trade-offs as tables and API designs as fenced code blocks.

## Acceptance Criteria
- Eval set: TODO recall ≥ 80%; trade-offs correctly paired ≥ 70%.
- Rendered Markdown passes markdownlint.
