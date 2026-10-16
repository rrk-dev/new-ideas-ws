# PRF-05 — Built-in Profile: Engineering / Brainstorming

**Workstream:** Profiles | **Phase:** 3 | **Size:** S | **Depends on:** PRF-01, PRF-02, LLM-05, PRF-09 | **Source:** §3.1.5
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-benchmark-eval, vv-markdown-vault-export, vv-testing

## Goal
Extract architectural concepts, API designs, trade-offs, and immediate TODOs from technical discussions.

## Scope
- [x] Schema: `title`, `context`, `concepts[]`, `api_designs[] {name, description, endpoints_or_signatures}`, `tradeoffs[] {option, pros, cons}`, `decisions[]`, `todos[]`, `open_questions[]`.
- [x] Technical vocabulary hints for STT (initial prompt) configurable by the user.
- [x] Template rendering trade-offs as tables and API designs as fenced code blocks.

## Acceptance Criteria
- Eval set: TODO recall ≥ 80%; trade-offs correctly paired ≥ 70%.
- Rendered Markdown passes markdownlint.

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** fix/prf · **Date:** 2026-10-15
- **Summary:** Built-in `engineering` profile verified by tests. New: user-configurable STT vocabulary (`VocabularyHints`, setting key `vocabulary.<profileId>`) merged with the profile vocabulary into the Whisper initial prompt (≤ 200 chars) by the transcribe step; new `code_lines` template lambda so API designs render as fenced code blocks (goldens + docs/templates.md updated); trade-offs render as `md_table`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [PRF-05/AC1]; device: docs/test-plans/device/PRF-05.md
  - AC2: ✅ test: [PRF-05/AC2]; device: docs/test-plans/device/PRF-05.md
- **Follow-ups:** see below.

## Follow-ups
- **Extraction-quality fix (profile v2):** no few-shot example, `api_designs`/`tradeoffs` only when discussed, caps ≤ 12, implicit dedupe + `ground_to_transcript`. Llama-3.2-1B engineering eval (30 cases, app prompt path): hallucination 69 % → 6 %, schema-valid 90 % → 100 %, TODO recall 16 % → 78 % (precision 15 % → 40 %), decisions recall 4 % → 85 %, title similarity 30 % → 73 %. 1B still over-extracts (precision ≤ 40 %, API-design recall 22 %): recommend a Llama-3.2-3B-class catalog model for this profile (not added here).
- Real-model eval numbers need a 3B-class model and the device lab (PRF-10); only SmolLM2-135M is available locally and the PRF-09 1B baselines are below target (prompts were re-tuned in fix/extraction-quality (profile v2, see below)).
- Settings UI to edit the per-profile vocabulary is not built (domain, key and transcribe wiring exist).
- Run `tools/ci/markdownlint.sh` (needs npx) on the engineering goldens; CI lints goldens.
- LIC-01: engineering tier is a placeholder `pro`.
