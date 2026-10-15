# LLM-05 — Structured Output via Constrained Decoding

**Workstream:** LLM | **Phase:** 2–3 | **Size:** M | **Depends on:** LLM-04, PRF-09 | **Source:** Gap (small models produce unreliable free-form Markdown; templates need structured data)
**Status:** review
**Skills:** vv-task-workflow, vv-llm-inference, vv-extraction-profiles, vv-ffi-bridge, vv-native-build, vv-benchmark-eval, vv-testing

## Goal
The LLM produces JSON matching each profile's output schema; Markdown is rendered from that JSON by the template engine (EXP-01), not written freehand by the model.

## Scope
- [x] Convert profile JSON Schema → GBNF grammar (llama.cpp `json_schema_to_grammar`). Static lib `vv_jsg` (json-schema-to-grammar.cpp, json-schema.cpp, json.cpp, trie.cpp, unicode.cpp + `bridge/vv_jsg_shim.cpp` for 4 string helpers; **no** llama-common — no HTTP symbols in the dylib), `vv_json_schema_to_gbnf`, Dart `VvNative.jsonSchemaToGbnf`, app `NativeSchemaGrammarConverter.toGbnf` (PRF-01 `SchemaGrammarConverter` signature, mirrored — PRF-01 is not merged).
- [x] Validate output against schema; on failure, one repair retry, then fall back to raw-summary mode. `OutputSchemaValidator` (profile-schema subset, content-free issue paths) + `StructuredExtractor` (grammar + extraction preset → validate → one greedy repair with issues + previous output → summary-only fallback with `valid = false`).
- [x] Handle grammar performance cost (measure tok/s impact). New default `VV_LLM_GRAMMAR_LAZY`: sample with the plain chain, check only the chosen token, full mask + resample only on rejection (llama.cpp common/sampling strategy); output byte-identical to the full mask under greedy (ctest `vv_grammar`). Host: 1B Metal none 98.5 / full 45.1 / lazy 103.4 tok/s; 1B CPU 32.6 / 24.7 / 35.4 — `tools/bench/results/2026-10-13-llm05-grammar.md`, tool `tools/bench/llm_grammar/`.
- [x] Evidence fields: optionally include transcript timestamps for each extracted item (traceability, reduces hallucination). `t` (`hh:mm:ss`) checked against `transcriptTimestamps(transcript)`; schema-aware cleanup: optional → removed, nullable → null, required non-null → item dropped; output stays schema-valid.

## Acceptance Criteria
- ≥ 99% of runs on the PRF-09 eval set produce schema-valid JSON.
- Grammar overhead on decode speed documented (< 20% target).

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist). Host spike measured GBNF decode overhead of −66% on Llama-3.2-1B (128k vocab, Metal, CPU-contended host) — the < 20% target needs work (see ADR-LLM-01 observations).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-05-structured-output (stacked on task/LLM-04-llm-ffi-engine) · **Date:** 2026-10-13
- **Summary:** Native: `native/bridge/vv_jsg.cpp`, `vv_jsg_shim.cpp`, CMake target `vv_jsg`, lazy grammar sampling + `grammar_mode` in `vv_llama_engine.cpp` / `vv_gen_params`; ctest `vv_grammar` (`native/tests/grammar_test.c`). Dart: `VvNative.jsonSchemaToGbnf`, `LlmGenParams.fullGrammarMask`; app `features/extraction/domain/output_schema_validator.dart`, `structured_extractor.dart`, `data/native_schema_grammar_converter.dart`; tests `test/unit/extraction/structured_extractor_test.dart`, `structured_extraction_host_test.dart`, device test `integration_test/llm_grammar_test.dart`. Benchmark tool `tools/bench/llm_grammar/` + results.
- **Host numbers:** grammar overhead (lazy) ≈ 0% vs −54% (Metal) / −24% (CPU) with the full mask (1B Q4_K_M, 3 runs, median); end-to-end SmolLM2-135M: 25/25 schema-valid on the first pass, 18 hallucinated evidence timestamps removed.
- **Acceptance evidence:**
  - AC1: ⏳ test: [LLM-05/AC1]; device: docs/test-plans/device/LLM-05.md
  - AC2: ⏳ artifact: tools/bench/results/2026-10-13-llm05-grammar.md; test: [LLM-05/AC2]; device: docs/test-plans/device/LLM-05.md
- **Decisions:** none new (lazy grammar = llama.cpp's own common/sampling strategy; ADR-LLM-01 observation resolved)
- **Follow-ups:** see below

## Follow-ups
- PRF-09 eval set is a hard dependency of AC1's "≥ 99% on the PRF-09 set" — re-run when it lands; the host test uses synthetic transcripts.
- PRF-01 merge: add `implements SchemaGrammarConverter` to `NativeSchemaGrammarConverter` and persist grammars in `ProfileGrammarCache` (PRF-01 follow-up).
- Profile spec (PRF-01): evidence `t` should be declared nullable or optional; a required non-null `t` makes the extractor drop items with unverifiable timestamps.


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ✅ tagged cleanup test and model-backed synthetic host suite passed (25/25 first pass). ❌ required evidence cleanup can return schema-invalid JSON with valid=true; the required PRF-09 eval corpus/harness is still todo and has not established ≥99%.
  - AC2: ✅ benchmark artifact documents full/lazy grammar rates and native lazy/full greedy equivalence passed. Device <20% benchmark test read; its runs remain ⏳.
- **Mutation sanity check:** Forced the transcript timestamp membership check to always succeed: `[LLM-05/AC1]` required-evidence cleanup test failed; restored with git checkout.
- **Adversarial checks:** Bad JSON/schema/grammar, one-repair/fallback and cancellation/OOM tests read and passed. External Flutter repro: schema requires root string t (maxLength 8), output {"t":"00:00:09"}, known timestamps {00:00:05}. Extractor returns data={} and valid=true although validator reports $.t: required.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/LLM-05.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:**
  1. `StructuredExtractor._accept` cleans after validation and never revalidates. If a required root t is unverifiable, clean returns the drop sentinel and _accept replaces it with {} while returning valid=true. Nested required objects/minItems can similarly be broken by removal. Revalidate cleaned output and route invalid results through the repair/fallback policy; never report invalid JSON as schema-valid.
  2. AC1 specifically requires ≥99% on the PRF-09 evaluation set. The tagged host test synthesizes only 25 transcripts with one schema; PRF-09 remains todo and tools/bench/eval/run.py is absent at this SHA. This is outstanding host evaluation work, not merely a pending physical-device row.

## Rework
- **Agent:** Claude Code · **Branch:** task/LLM-05-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged).
- **Issue 1 (cleanup not revalidated → `valid=true` for schema-invalid data):** reproduced first with four new
  `[LLM-05/AC1]` tests in `app/test/unit/extraction/structured_extractor_test.dart` (group
  "cleanup is revalidated (rework-1)"; red at commit `acb8c09`): the verifier's exact case (root required `t`,
  `maxLength 8`, answer `{"t":"00:00:09"}`, transcript `{00:00:05}`), a list dropping below `minItems`, a required
  nested object (previously the internal drop sentinel was even stored as a map value), and an optional nested
  object. Fix in `app/lib/features/extraction/domain/structured_extractor.dart`: each answer now goes
  parse → validate → evidence cleanup → **full revalidation** (`_attempt`). Only data that passes the schema after
  cleanup is returned with `valid = true`. Otherwise the answer counts as a failed attempt: first answer → the one
  greedy repair (prompt lists content-free issues such as `$.t: evidence timestamp not found in transcript` plus
  validator rules like `$.items: fewer than minItems 1`; never the invented value), repair answer →
  summary-only fallback / `valid = false` (`summaryFallback: false` for LLM-06 map chunks). Cleanup drop rules are
  now total: a dropped object under a required key propagates upward, under an optional key it is removed, in a
  list the item is removed; a dropped root yields no data. The existing nullable/optional cleanup behaviour and the
  25/25 synthetic host case are unchanged.
- **Issue 2 (AC1 needs ≥ 99% on the PRF-09 eval set):** not resolvable in this task — PRF-09 (eval corpus +
  `tools/bench/eval/run.py`) is still `todo` and is a declared dependency. AC1 stays **⏳ pending PRF-09**; the
  host tests prove the validity contract (no schema-invalid output is ever reported as valid), not the ≥ 99% rate.
  The last row of `docs/test-plans/device/LLM-05.md` holds the exact run to perform once PRF-09 lands
  (summary-only fallbacks count as invalid). Nothing here claims that run happened.
- **Gates (2026-10-14):** format ✅ · `flutter analyze` ✅ no issues · `flutter test test/unit/extraction` ✅ 68 passed · `tasks.py validate` ✅. Full suite runs in the wave-4 integration.
