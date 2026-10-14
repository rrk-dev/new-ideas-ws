# FND-11 — Production Engine Wiring

**Workstream:** Foundation | **Phase:** 2–3 | **Size:** L | **Depends on:** FND-05, AUD-01, STT-03, LLM-05, LLM-07, EXP-01, EXP-02, MDL-02, LIC-01 | **Source:** Gap (engines, renderer and export exist but the app's pipeline worker had no production engine factory)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-pipeline-orchestrator, vv-flutter-architecture, vv-whisper-stt, vv-llm-inference, vv-markdown-vault-export, vv-model-delivery, vv-testing

## Goal
In the real app (not only in tests) a finished recording flows through the pipeline worker with the
real engines — whisper.cpp transcription, grammar-constrained llama.cpp extraction, Mustache rendering
and a vault write — using the models the user installed, and waits (instead of failing) when none is.

## Scope
- [ ] Production `pipelineEnginesFactoryProvider` default: the worker factory builds a `WhisperSttEngine`
      and an `LlmService` for the **active installed models** (MDL-02 `models_installed`), picked on the
      UI isolate from the user's preference, LLM-07 tier × plan defaults (`defaultsFor`) and LIC-01's
      `EntitlementService` (`Feature.largeLlm`, model tier access), published to the worker through the DB.
- [ ] One shared `ModelResidency` + `HeavyModelGate` in the worker: STT and LLM are never loaded together;
      the LLM is unloaded when the queue is idle.
- [ ] `schemaGrammarConverterProvider` default = `NativeSchemaGrammarConverter`; `ExtractStep` uses the
      profile grammar + `StructuredExtractor` (validation, repair, summary fallback) when the worker has a
      profile resolver (placeholder prompt stays the PRF-02 seam).
- [ ] `RenderStep` renders with `TemplateNoteRenderer`: `BuiltinProfiles` / `BuiltinTemplates` asset text
      loaded on the UI isolate before the worker starts, plus a DB snapshot of user profiles/templates at
      job start.
- [ ] `WriteStep` uses EXP-02's `FilenamePattern` (profile pattern → setting → default), `ExportIdentity`
      + `planExport` (collision mode setting) and a `VaultWriter` for the configured vault target
      (app-local / SAF / bookmark; platform channels from the worker via `BackgroundIsolateBinaryMessenger`).
- [ ] `JobMetrics` (FND-07) recorded for the transcribe/extract steps from STT/LLM stats (audio duration,
      prompt/generated tokens, prefill/decode time) into the app's metrics file.
- [ ] No active model of a step's type ⇒ the job goes to `waiting(model_missing)`; it resumes when a
      model becomes available (publisher calls `resolveWaiting`).
- [ ] App foreground/background state forwarded to the worker (GPU only in the foreground — backend
      policy of STT-03 / LLM-04).

## Acceptance Criteria
- App bootstrap creates real engines: with no `pipelineEnginesFactoryProvider` override, the provider
  builds a factory whose engines are the whisper/llama-backed STT and LLM engines, the
  `TemplateNoteRenderer` with all built-in profiles and templates, a per-target vault writer and the
  shared residency gate, and `schemaGrammarConverterProvider` is the native converter (provider test).
- End-to-end host integration test with the real tiny models from `tools/ci/fetch_test_models.sh`
  (`ggml-tiny.en`, SmolLM2-135M) and `jfk.wav`, through the production providers and the worker
  isolate: one recording becomes exactly one note file in an app-local vault target whose YAML
  front-matter parses with `source: vaultvoice`, `recording_id` = the recording and a non-empty
  title; the stored transcript contains "country"; `exports` holds one `written` row; JobMetrics for
  transcribe (audio duration > 0) and extract (generated tokens > 0) are written.
- With no models installed the job ends in `waiting(model_missing)` (not `failed`) and no engine is
  invoked; installing a model and publishing it resumes the job to `done`.
- The same flow (record or import → note in the app-local vault, front-matter valid) passes on a
  physical iPhone and a physical Android device with the tiny models (device rows).
