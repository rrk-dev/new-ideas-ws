# ASK-03 — Ask-your-notes engine (retrieve, generate, cite)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** L | **Depends on:** ASK-01, ASK-02, LLM-04, LLM-05, LLM-07, FND-04, SEC-04 | **Source:** User decision 2026-10-16 (product Phase 2: ask-your-notes across the library)
**Status:** todo
**Skills:** vv-task-workflow, vv-llm-inference, vv-local-database, vv-flutter-architecture, vv-pipeline-orchestrator, vv-privacy-security, vv-benchmark-eval, vv-testing

## Goal
A domain-layer engine answers a natural-language question about the user's library using the approach chosen in ADR-ASK-02, returning an answer with citations (recording id + timestamp) or an explicit "not found".

## Scope
- [ ] Domain interface and fake (`AskEngine`, `AskAnswer`, `Citation`) following `vv-flutter-architecture` (engine interfaces with fakes); no UI here.
- [ ] Retrieval per ADR-ASK-02 over transcripts and extracted fields, with an explicit optional `recordingId` scope (per-recording Ask must never retrieve another recording's passages) plus optional date/profile/tag filters parsed deterministically in Dart (not asked of the LLM).
- [ ] Prompt builder and grammar-constrained answer schema (`answer`, `citations[] {recording_id, t}`, `found`) reusing the LLM-05 constrained-output path; citations are validated against retrieved passages and dropped if they do not exist.
- [ ] Residency: acquire the LLM through `ModelResidency`, never while STT is resident; behaviour when a transcription job is running is the one defined in the ADR; cancel/timeout supported.
- [ ] Persisted chat history only if the ADR says so, in the encrypted DB with a drift migration, deletion cascade and partial-retention handling (when SEC-04 expires transcripts/notes but keeps audio, `recording_purger.dart`, stored answers, passages and citations derived from them are purged too) (`vv-local-database`); question/answer text never logged.
- [ ] Refuse politely when the 3B model is not installed or the device tier cannot run it (typed `Failure`, no crash); never fall back to a cloud call.
- [ ] Eval hook in `tools/bench/eval/` that runs the ASK-02 question set end to end against the engine and reports answer correctness, citation precision, unanswerable-refusal rate, hallucination rate and latency.

## Acceptance Criteria
- On the ASK-02 question set with the 3B model on the host: citation precision ≥ 90% and unanswerable questions correctly refused ≥ 90%; the answer-correctness target is written into this file before the first run and the report is committed (artifact).
- A citation that points to a non-retrieved or non-existent passage is never returned (unit test `[ASK-03/AC2]`).
- With STT resident, asking never loads the LLM alongside it (residency unit test `[ASK-03/AC3]`).
- Deleting a recording removes it from retrieval and from any stored chat citations (DB test `[ASK-03/AC4]`).
- No question, answer or passage text appears in logs at INFO or above (log-content test `[ASK-03/AC5]`); `check_egress.sh` shows no new host.
- A per-recording Ask never returns a passage from another recording (unit/eval test `[ASK-03/AC7]`); after transcript expiry with audio retained, no stored answer or citation derived from it remains (DB test `[ASK-03/AC8]`).
- Per-tier budgets (Mid and High: median time-to-first-answer with a 100-recording library, peak RAM, thermal state) are written into this file with the measurement protocol (QA-03) before the first run and measured on device (device row); GATE-05 checks against them.
