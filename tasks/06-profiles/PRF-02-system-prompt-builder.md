# PRF-02 — System Prompt Builder

**Workstream:** Profiles | **Phase:** 2 (pulled forward: needed by LLM-05 / PRF-09 / GATE-02) | **Size:** M | **Depends on:** PRF-01, LLM-04 | **Source:** §5 Phase 3
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-llm-inference, vv-testing

## Goal
Assemble the final prompt from profile + transcript + context, within the token budget.

## Scope
- [x] Compose: system prompt, profile instructions, few-shot examples, metadata (date, duration, speakers, user markers from AUD-08), transcript (speaker-labelled), output-schema reminder.
- [x] Apply model chat template from GGUF.
- [x] Token budgeting: trim examples first, then hand off to LLM-06 map-reduce when transcript exceeds budget.
- [x] Prompt-injection hygiene: transcript is clearly delimited as data (someone may *say* "ignore previous instructions").
- [x] Snapshot tests of rendered prompts.

## Acceptance Criteria
- Prompt snapshots stable across runs; budget never exceeded (unit-tested with large transcripts).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/PRF-02-system-prompt-builder · **Date:** 2026-10-14
- **Summary:** `PromptBuilder` (`app/lib/features/profiles/domain/prompt_builder.dart`) assembles the
  prompt in the `vv-extraction-profiles` order: one `system` message (fixed extraction prompt +
  profile instructions + field descriptions generated from the schema by
  `schema_prompt_text.dart`), few-shot examples as `user`/`assistant` pairs (output as compact
  canonical JSON in schema order), `user` message with metadata (date + weekday, duration, speaker
  display names, AUD-08 user markers), the `<transcript>` block (`[hh:mm:ss] Name: text`) and the
  output-schema reminder. Inputs in `prompt_inputs.dart`. The chat template and exact counts come
  from a `PromptTokenizer` — `SessionPromptTokenizer` (`profiles/data/`) over LLM-04's `LlmSession`
  (`vv_llm_apply_chat_template` / `vv_llm_count_tokens`, same `add_special`+`parse_special`
  tokenization as generation, so the count equals the prefill count — verified on SmolLM2).
  Budget: `prompt + max_tokens ≤ n_ctx`; examples dropped last-first; then `MapReducePrompt`
  (hand-off interface for LLM-06: `chunkTranscriptBudget`, `segmentTokens`, `renderChunk` with
  `map_schema`, "part i of n" header, refuses over-budget chunks) or `PromptTooLarge`.
  Injection hygiene: `<`/`>` → `‹`/`›` in transcript text, speaker names and marker labels
  (neutralizes `</transcript>` and `<|im_end|>`-style special tokens, which the bridge would parse),
  line breaks collapsed (no forged lines). Snapshots in `app/test/golden_prompts/` (3 built-ins +
  a map-reduce chunk). CLI `app/tool/render_prompt.dart` (+ `tool/src/prompt_case.dart`) renders a
  case exactly like the app (exact with `--model` via `vv_native`; ChatML/approx otherwise) and, with
  `--generate --cases x.jsonl`, runs grammar-constrained generation through the host build for
  PRF-09. Spec section "Prompt assembly" added to `docs/profile-spec.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [PRF-02/AC1]
- **Decisions:** no ADR (no technology choice). One merged `system` message instead of two (several
  GGUF templates — e.g. Gemma — accept only one leading system turn). Untrusted `<`/`>` are replaced
  rather than escaped (STT output practically never contains them; replacement cannot be undone by
  the model). Gates: format 0 changed, `flutter analyze` / `dart analyze --fatal-infos` 0 issues,
  `flutter test` 803 passed / 24 skipped.
- **Follow-ups:** see below.

## Integration (coordinator request, 2026-10-14)
- Seam for callers that pass system + user strings to `LlmEngine` / `StructuredExtractor`:
  `ExtractionPrompts` (`app/lib/features/profiles/domain/extraction_prompts.dart`) via
  `extractionPromptsProvider` (`profiles/data/profile_providers.dart`, factory
  `(profile, {metadata}) → ExtractionPrompts`): `systemPrompt` (shared KV prefix), `chunkSystemPrompt`,
  `transcriptLines(segments)` (sanitized), `singleUser(lines, {withExamples})`, `chunkUser(lines, index:, count:)`.
- **FND-11 swap** (`pipeline/data/steps/extract_step.dart` `_structured`): replace `kInterimExtractionSystemPrompt` and the
  `'${profile.instructions}\n\n<transcript>…'` user prompt with `p.systemPrompt` / `p.singleUser(p.transcriptLines(segs))`
  where `p = ref.read(extractionPromptsProvider)(profile, metadata: …)` and `segs` = `TranscriptSegmentRow` →
  `PromptSegment(start: Duration(milliseconds: startMs), speaker: speaker, text: body)` (speaker display names via
  `PromptMetadata.speakers`); keep `transcriptTimestamps(p.transcriptLines(segs))`. Delete `timestampedTranscript` and the
  interim constant. Exact budgeting (`PromptBuilder.build` + `SessionPromptTokenizer`) needs a tokenizer from `LlmService` —
  follow-up below.
- **LLM-06 swap** (`extraction/domain/long_transcript/extraction_prompts.dart`): make `ProfilePromptSource` delegate to
  `ExtractionPrompts` — `systemPrompt` → `p.systemPrompt` (or `p.chunkSystemPrompt` for map calls), `singleUser(block, …)` →
  `p.singleUser(lines, withExamples: …)`, `chunkUser(block, info)` → `p.chunkUser(lines, index: info.index, count: info.count)`;
  build the transcript text with `p.transcriptLines(...)` instead of `transcriptBlock`/`escapeTranscript` (the PRF-02 user
  message adds the `<transcript>` tags itself and neutralizes `<`/`>`). `reduceUser` stays in LLM-06.
- Output budget: the fixed system prompt now asks for compact single-line JSON and short texts, and the reminder says
  "Return one compact JSON object…" (FND-11 e2e hit the 1024-token cap with the meeting schema).

## Follow-ups
- Wiring / LLM-05: `ExtractStep` still uses its placeholder prompt; replace it with `PromptBuilder`.
  Needs (a) a tokenizer from the loaded model — e.g. an additive `LlmService.withSession` /
  `promptTokenizer()` returning `SessionPromptTokenizer` — and (b) `StructuredExtractor` accepting a
  pre-templated `BuiltPrompt` (`LlmRequest(templated: true)`) so few-shot pairs are not lost (today
  it takes only `systemPrompt` + `userPrompt`); the repair attempt can append a `user` turn to
  `BuiltPrompt.messages`. Transcript rows → `PromptSegment` and speakers/markers → `PromptMetadata`.
- LLM-06: implement chunking over `MapReducePrompt` (segment boundaries, ~10 % overlap,
  `renderChunk` returns null → split smaller).
