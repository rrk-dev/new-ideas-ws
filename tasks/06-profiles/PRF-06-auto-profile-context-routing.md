# PRF-06 — Automatic Profile Classification ("Context Routing")

**Workstream:** Profiles | **Phase:** 3 | **Size:** M | **Depends on:** PRF-03, PRF-04, PRF-05, PRF-09 | **Source:** §3.1.3 (Local LLM Engine & Context Routing)
**Status:** todo
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-llm-inference, vv-benchmark-eval, vv-pipeline-orchestrator, vv-testing

## Goal
When the user picks "Auto", the app selects the best profile (and therefore template and destination) from transcript content.

## Scope
- [ ] Lightweight classification prompt on the first N tokens with constrained output (enum of profile ids + confidence).
- [ ] Optional keyword pre-filter rules ("warranty", "serial number") for speed.
- [ ] Low-confidence → ask user (notification / in-app chooser) before extraction.
- [ ] Allow user override after the fact and re-run extraction.

## Acceptance Criteria
- ≥ 90% correct profile selection on a mixed eval set.
- Classification adds < 10 s on mid-tier devices.
