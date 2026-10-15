# FND-11 — Production Engine Wiring

**Workstream:** Foundation | **Phase:** 2–3 | **Size:** L | **Depends on:** FND-05, AUD-01, STT-03, LLM-05, LLM-07, EXP-01, EXP-02, MDL-02, LIC-01 | **Source:** Gap (engines, renderer and export exist but the app's pipeline worker had no production engine factory)
**Status:** review
**Skills:** vv-task-workflow, vv-pipeline-orchestrator, vv-flutter-architecture, vv-whisper-stt, vv-llm-inference, vv-markdown-vault-export, vv-model-delivery, vv-testing

## Goal
In the real app (not only in tests) a finished recording flows through the pipeline worker with the
real engines — whisper.cpp transcription, grammar-constrained llama.cpp extraction, Mustache rendering
and a vault write — using the models the user installed, and waits (instead of failing) when none is.

## Scope
- [x] Production `pipelineEnginesFactoryProvider` default: the worker factory builds a `WhisperSttEngine`
      and an `LlmService` for the **active installed models** (MDL-02 `models_installed`), picked on the
      UI isolate from the user's preference, LLM-07 tier × plan defaults (`defaultsFor`) and LIC-01's
      `EntitlementService` (`Feature.largeLlm`, model tier access), published to the worker through the DB.
- [x] One shared `ModelResidency` + `HeavyModelGate` in the worker: STT and LLM are never loaded together;
      the LLM is unloaded when the queue is idle.
- [x] `schemaGrammarConverterProvider` default = `NativeSchemaGrammarConverter`; `ExtractStep` uses the
      profile grammar + `StructuredExtractor` (validation, repair, summary fallback) when the worker has a
      profile resolver (placeholder prompt stays the PRF-02 seam).
- [x] `RenderStep` renders with `TemplateNoteRenderer`: `BuiltinProfiles` / `BuiltinTemplates` asset text
      loaded on the UI isolate before the worker starts, plus a DB snapshot of user profiles/templates at
      job start.
- [x] `WriteStep` uses EXP-02's `FilenamePattern` (profile pattern → setting → default), `ExportIdentity`
      + `planExport` (collision mode setting) and a `VaultWriter` for the configured vault target
      (app-local / SAF / bookmark; platform channels from the worker via `BackgroundIsolateBinaryMessenger`).
- [x] `JobMetrics` (FND-07) recorded for the transcribe/extract steps from STT/LLM stats (audio duration,
      prompt/generated tokens, prefill/decode time) into the app's metrics file.
- [x] No active model of a step's type ⇒ the job goes to `waiting(model_missing)`; it resumes when a
      model becomes available (publisher calls `resolveWaiting`).
- [x] App foreground/background state forwarded to the worker (GPU only in the foreground — backend
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

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-11-production-engine-wiring (base origin/main 67b6fcf, not stacked) · **Date:** 2026-10-14
- **Summary:**
  - Worker factory: `PipelineEnginesFactory` now takes a `PipelineWorkerContext` (worker DB + paths);
    `pipelineEnginesFactoryProvider` defaults to `ProductionEngineSpec.build`
    (`features/pipeline/data/production_engines.dart`; spec = sendable asset text, app-local vault root,
    metrics file, platform, root isolate token, lifecycle; provider `engine_providers.dart`).
  - Engines (`active_engines.dart`): `InstalledModelResolver` (published id → `models_installed` row of the
    right type → file inside the storage root), `ActiveSttEngine` (one `WhisperSttEngine` per active model),
    `ActiveLlmEngine` (one `LlmService` per model/context: LLM-07 `planLlmLoad` gate, tier context, shared
    `chooseLlmBackend` policy, `onStats`), one `ModelResidency` + `HeavyModelGate` (release unloads the engine);
    the orchestrator now releases the loaded model when the queue is idle.
  - Selection (`domain/active_models.dart`, `data/active_models_publisher.dart`): `selectActiveModels` on the UI
    isolate (user preference `models.active_stt/llm` → LLM-07 `defaultsFor` → fallback; LIC-01
    `FeatureAccess.model(...)` + `Feature.largeLlm`; catalog `min_ram_mb`), published to `pipeline.active_models`
    before the worker spawns and on every install/preference/entitlement change; `resumeModelWaits` then
    resolves `waiting(model_missing)` jobs.
  - Steps: Transcribe/Extract wait with `model_missing` when no active model and record the real model id;
    `ExtractStep` uses profile grammar + `StructuredExtractor` (interim system prompt, PRF-02 seam) and an
    `ExtractionStrategy` seam for LLM-06; `RenderStep` builds `TemplateNoteRenderer` per job (built-ins +
    DB snapshot of user profiles/templates) and stores action items from `task`/`text` with owner/`due_iso`/`t`
    (fixes Meeting items being dropped); `WriteStep` uses `FilenamePattern` (profile → setting → default),
    `ExportIdentity` + `planExport` (collision setting) and a per-target writer (app-local / SAF / bookmark via
    `BackgroundIsolateBinaryMessenger`; refreshed bookmarks stored back).
  - `JobMetrics` for transcribe/extract (`PipelineJobMetrics`); `schemaGrammarConverterProvider` defaults to
    `NativeSchemaGrammarConverter`; `nativeLibraryPathProvider` (core) for host runs; `ProcessingServicesHost`
    forwards lifecycle + memory pressure to a running worker (`PipelineConditions`).
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-11/AC1]
  - AC2: ✅ test: [FND-11/AC2]
  - AC3: ✅ test: [FND-11/AC3]
  - AC4: ⏳ device: docs/test-plans/device/FND-11.md
- **Host run (AC2, M-series Mac, CPU):** transcribe 11 s audio in 1.8 s (RTF 0.17); extract 1864 prompt /
  2253 generated tokens (two grammar passes hit the 1024-token cap with SmolLM2-135M → summary fallback,
  `extraction: failed` front-matter — expected for the 135M model); test ≈ 60–100 s.
- **Decisions:** no ADR (no technology choice). PRODUCT-DECISIONs: fallback model choice = largest usable model
  recommended for the device tier, else the smallest usable (`active_models.dart`); models unknown to the catalog
  (sideload) count as Free tier, LLM files > 1.2 GB as large; no vault target still waits with `destination`
  (no automatic app-local fallback); `skip` collision mode records no export.
- **Changed FND-05 tests (intentional behaviour changes):** note path now follows the filename pattern
  (`<date>-meeting.md` instead of `<recording>.md`), and the LLM is released when the queue is idle.
- **Follow-ups:** see below.

## Follow-ups
- Codex review 2026-10-15 (fixed, regression-tested): Profile preview LLM load is not serialized through the worker's model gate; a job can start STT after the preview's pipeline-activity check (preview_llm_engine.dart:53); add overlap test.
- **LLM-06 integration (branch task/LLM-06-long-transcript-map-reduce, not merged here):** drop LLM-06's
  `ExtractStep.longTranscript` parameter in favour of `PipelineEngines.extraction` (`ExtractionStrategy`): wrap
  `LongTranscriptExtraction` (extractor + `inputFor` + `_StepCheckpoints(ctx)`) in an adapter implementing
  `ExtractionStrategy.extract(ctx, profile:, grammar:, segments:, maxTokens:)`, returning null when the plan is a
  single pass; build it in `ProductionEngineSpec.build` with `ActiveLlmEngine` + LLM-06's `LlmTokenizer`
  (needs the current `LlmService` session — expose it from `ActiveLlmEngine.service`) and the device tier from
  the published selection; store the step's resolved model id (not `config.llmModelId`) and the fallback as
  `{title, summary}` (`ExtractStep.fallbackExtractionJson`) so `summary-only` renders it.
- PRF-02: replace the interim prompt in `ExtractStep._structured` (and LLM-06's `ProfilePromptSource`).
- MDL-03: write `models.active_stt` / `models.active_llm` on "set active" (the publisher already reacts).
- AUD-08: enqueue the finished recording (`pipelineClient.enqueue(id, userInitiated: true)`) when
  `processing.auto_process` is on — the controller's `stop()` does not enqueue today.
- FND-08: pause/background tasks on top of `PipelineConditions`; GPU trial store (`fileGpuTrialGuard`)
  crashed set is not yet passed to `chooseLlmBackend` in the worker; Android GPU backends are not loaded.
- EXP-05/06: routing rules and multi-target; `VaultWriter` read/hash for user-edit detection (`currentHash`).
- Token budget: the Meeting schema with 1024 `maxLlmTokens` truncates on tiny models (LLM-06/PRF-02 budgets).
