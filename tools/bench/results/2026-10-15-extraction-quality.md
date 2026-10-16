# Extraction quality fix: before / after (Llama-3.2-1B-Instruct Q4_K_M)

Model: `Llama-3.2-1B-Instruct-Q4_K_M`, host build with Metal, app prompt path
(`render_prompt.dart --app-path`, i.e. `ExtractionPrompts`), 30 synthetic cases per profile,
n_ctx 4096. "Before" is origin/main (ebf4ff7a) with the same harness.

## Root causes (evidence)

1. **Example leakage.** `ExtractionPrompts.singleUser` inlined the profile's few-shot
   `Example transcript … Example JSON …` immediately before the real transcript. The 1B model
   copied the example JSON ("Sync strategy", change log, `GET /changes?since=cursor`, Omar, Lena)
   for both reported recordings (~1000-char transcripts, ~1200 prompt tokens, no truncation,
   no map-reduce). The eval harness used the chat-pair `PromptBuilder` path, so it never saw it.
2. **Loops.** Extraction preset had repeat penalty 1.0 and `maxItems` 20–30; `dedupe_lists`
   existed but was not listed by the built-in profiles, so 343 `open_questions` were emitted over
   30 engineering cases (20 × "What is the commit?").
3. **No grounding.** Nothing checked the output against the transcript.

## Fixes

Profiles v2 (no examples, "only what the transcript states", caps ≤ 12), system prompt rules,
implicit `dedupe_lists`, `ground_to_transcript` (meeting, engineering), repeat penalty 1.05.

## Results (app path)

| Profile / metric | Before | After |
|---|---|---|
| engineering schema-valid | 90 % | 100 % |
| engineering hallucination | 68.5 % | 5.9 % |
| engineering TODO recall / precision | 15.6 / 15.2 % | 78.1 / 40.3 % |
| engineering decisions recall | 3.8 % | 84.6 % |
| engineering concepts recall | 11.1 % | 75.0 % |
| engineering trade-offs recall | 75.0 % | 75.0 % |
| engineering api_designs recall / precision | 11.1 / 1.9 % | 22.2 / 2.8 % |
| engineering title similarity | 30 % | 73 % |
| meeting hallucination | 75.5 % | 0 % |
| meeting action items recall / precision | 2.4 / 3.2 % | 88.1 / 54.4 % |
| meeting owner accuracy | 100 % (of 2 %) | 67.6 % |
| meeting title similarity | 32 % | 75 % |
| warranty hallucination | 39.4 % | 33.9 % |
| warranty serial exact | 13 % | 33 % |
| warranty exact-field accuracy | 35 % | 45 % |

Sampler check (engineering): repeat penalty 1.0 (grammar only) todos recall 68.8 %,
1.05 → 78.1 %, 1.1 → 65.6 % with decisions recall dropping to 61.5 %; 1.05 chosen.

Grounding false positives on the gold outputs: 3/4 gold items dropped and 4/2 titles replaced
(meeting/engineering, 30 cases each), 0 for warranty.

Real recordings f103f9ca / 230966b7 after the fix: titles "Tenancy Commitment Review" and
"Match the trust boundary"; no example text, no repetition loops.

## Remaining limitation

The 1B model still over-extracts on the engineering profile (precision ≤ 40 %, API-design
recall 22 %, meeting action-item precision 54 % < 80 % target) and copies transcript lines into
the wrong fields. A 3B-class model (e.g. Llama-3.2-3B-Instruct Q4_K_M) is recommended for
`engineering`; it is not added to the catalog here.
