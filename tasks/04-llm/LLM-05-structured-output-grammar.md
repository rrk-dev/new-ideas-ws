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
