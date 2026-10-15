# PRF-06 — Automatic Profile Classification ("Context Routing")

**Workstream:** Profiles | **Phase:** 3 | **Size:** M | **Depends on:** PRF-03, PRF-04, PRF-05, PRF-09 | **Source:** §3.1.3 (Local LLM Engine & Context Routing)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-llm-inference, vv-benchmark-eval, vv-pipeline-orchestrator, vv-testing

## Goal
When the user picks "Auto", the app selects the best profile (and therefore template and destination) from transcript content.

## Scope
- [x] Lightweight classification prompt on the first N tokens with constrained output (enum of profile ids + confidence).
- [x] Optional keyword pre-filter rules ("warranty", "serial number") for speed.
- [x] Low-confidence → ask user (notification / in-app chooser) before extraction.
- [x] Allow user override after the fact and re-run extraction.

## Acceptance Criteria
- ≥ 90% correct profile selection on a mixed eval set.
- Classification adds < 10 s on mid-tier devices.

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** fix/prf · **Date:** 2026-10-15
- **Summary:** `ProfileClassifier` (keyword pre-filter, then grammar-constrained LLM call on the first ~1500 tokens; confidence < 0.6 ⇒ ask) and `ClassifyStep` in the pipeline before extraction for recordings with no profile ("Auto"). Confident result sets `recordings.profile_id`; low confidence ⇒ `waiting(profileChoice)`; the existing changeProfile/`rerun(profileId)` allows override and re-extract. Keyword stage decides 23/90 eval transcripts with 0 wrong.
- **Acceptance evidence:**
  - AC1: ⏳ test: [PRF-06/AC1]; device: docs/test-plans/device/PRF-06.md
  - AC2: ⏳ test: [PRF-06/AC2]; device: docs/test-plans/device/PRF-06.md
- **Follow-ups:** see below.

## Follow-ups
- ≥ 90 % on the mixed set needs the real LLM (only the keyword stage is measured here); < 10 s latency needs a device (rows).
- A dedicated chooser UI/notification for `waiting(profileChoice)` is not built; the recording-detail changeProfile action is reused.
