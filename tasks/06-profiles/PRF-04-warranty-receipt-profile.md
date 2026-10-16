# PRF-04 — Built-in Profile: Warranty & Receipt Logger

**Workstream:** Profiles | **Phase:** 3 | **Size:** S | **Depends on:** PRF-01, PRF-02, LLM-05, PRF-09 | **Source:** §3.1.5
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-benchmark-eval, vv-markdown-vault-export, vv-testing

## Goal
From a short spoken note, extract product name, purchase date, serial number, warranty period and support contacts.

## Scope
- [x] Schema: `product`, `brand`, `model`, `serial_number`, `purchase_date`, `retailer`, `price`, `warranty_period`, `warranty_expiry` (computed in Dart, not by LLM), `support_contacts[]`, `notes`.
- [x] Spelling-aware extraction for serial numbers (users spell alphanumerics: "S as in Sam…"); normalize.
- [x] Relative date resolution ("bought it last Tuesday") using recording date — done deterministically after extraction.
- [x] Template with front-matter suitable for Obsidian Dataview queries (e.g., list warranties expiring soon).
- [x] Diarization off by default.

## Acceptance Criteria
- ≥ 90% field accuracy on warranty eval set; serial numbers exact-match ≥ 85%.
- Expiry date computed correctly in unit tests (including leap years, month-end).

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** fix/prf · **Date:** 2026-10-15
- **Summary:** Built-in `warranty` profile with deterministic post-processing (serial normalisation of spelled characters, relative-date resolution, expiry computed in Dart incl. leap years/month-end), Dataview-friendly template, diarization off. Branch merged from origin/task/PRF-04-warranty-profile; tests tagged.
- **Acceptance evidence:**
  - AC1: ⏳ test: [PRF-04/AC1]; device: docs/test-plans/device/PRF-04.md
  - AC2: ✅ test: [PRF-04/AC2]
- **Follow-ups:** see below.

## Follow-ups
- **Extraction-quality fix (profile v2):** no few-shot example, no sample values in the instructions, `ground_to_transcript` not used (it would drop spelled serials/contacts). Llama-3.2-1B warranty eval (30 cases): hallucination 39 % → 34 %, serial exact 13 % → 33 %, exact-field accuracy 35 % → 45 %, support contacts recall 0 % → 89 %. See tools/bench/results/2026-10-15-extraction-quality.md.
- Real-model eval numbers need a 3B-class model and the device lab (PRF-10); only SmolLM2-135M is available locally and the PRF-09 1B baselines are below target (prompts were re-tuned in fix/extraction-quality (profile v2, see below)).
- LIC-01: warranty tier is a placeholder `pro` (PRODUCT-DECISION).
