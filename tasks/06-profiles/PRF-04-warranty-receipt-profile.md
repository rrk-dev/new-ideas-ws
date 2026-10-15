# PRF-04 — Built-in Profile: Warranty & Receipt Logger

**Workstream:** Profiles | **Phase:** 3 | **Size:** S | **Depends on:** PRF-01, PRF-02, LLM-05, PRF-09 | **Source:** §3.1.5
**Status:** in-progress
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-benchmark-eval, vv-markdown-vault-export, vv-testing

## Goal
From a short spoken note, extract product name, purchase date, serial number, warranty period and support contacts.

## Scope
- [ ] Schema: `product`, `brand`, `model`, `serial_number`, `purchase_date`, `retailer`, `price`, `warranty_period`, `warranty_expiry` (computed in Dart, not by LLM), `support_contacts[]`, `notes`.
- [ ] Spelling-aware extraction for serial numbers (users spell alphanumerics: "S as in Sam…"); normalize.
- [ ] Relative date resolution ("bought it last Tuesday") using recording date — done deterministically after extraction.
- [ ] Template with front-matter suitable for Obsidian Dataview queries (e.g., list warranties expiring soon).
- [ ] Diarization off by default.

## Acceptance Criteria
- ≥ 90% field accuracy on warranty eval set; serial numbers exact-match ≥ 85%.
- Expiry date computed correctly in unit tests (including leap years, month-end).
