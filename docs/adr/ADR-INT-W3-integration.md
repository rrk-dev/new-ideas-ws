# ADR-INT-W3 — Wave-3 integration decisions (one engine wiring, one VAD, one catalog key)

- **Status:** Proposed (host-verified; device rows of the merged tasks still pending)
- **Date:** 2026-10-14
- **Task:** none (integration branch `integration/wave-3`; merges FND-11, FND-08, LLM-06,
  PRF-02/07/08/09, STT-04/06/07, AUD-02/03/06/08, EXP-05/06/07/08, APP-01/02/05, MDL-03,
  SEC-01/02/03/04, QA-02, REL-03 with `git merge --no-ff`, in dependency order)
- **Deciders:** Claude Code (integration engineer); pending verifier and the user
- **Builds on:** ADR-INT-W2 (one native backend design / backend policy)

## Context
The 28 wave-3 branches were built in parallel against `main` (67b6fcf). Several of them
introduced the same seam twice (two `VadEngine` interfaces, two catalog signing keys with the
same name, two extraction-prompt sources, two vault-writer resolvers, two ways to route a note),
or left a "wire me in" note for a seam another branch owned (FND-11 production engines ↔ PRF-02,
LLM-06, EXP-05/07, STT-07, MDL-03; AUD-08 ↔ APP-01; APP-02/05 ↔ STT-06; APP-02 ↔ SEC-04;
PRF-07 ↔ the real LLM). The integration must produce one design without adding features.

## Decisions
1. **Extraction = FND-11's `ExtractionStrategy` seam.** LLM-06's `ExtractStep(longTranscript:)`
   parameter is dropped; `LongTranscriptStrategy` (`pipeline/data/long_transcript_strategy.dart`)
   adapts `LongTranscriptExtraction` and is built in `ProductionEngineSpec.build` (exact token
   budgets from the active model — `ActiveLlmEngine` is now also the `LlmTokenizer` — tier from
   total RAM, checkpoint key = resolved model id + profile id@version). The strategy receives the
   step's **resolved** model id and the recording metadata. The extractor itself plans single pass
   vs map-reduce, so short transcripts take the same structured single pass. A failed structured
   pass is stored as `{title, summary}` (`ExtractStep.fallbackExtractionJson`).
2. **Prompts = PRF-02.** FND-11's `kInterimExtractionSystemPrompt` / `timestampedTranscript` are
   gone: the profile path uses `ExtractionPrompts` (system prompt, sanitized `[hh:mm:ss] Name:`
   lines, metadata: date, duration, speaker names, user markers). LLM-06's `ExtractionPromptSource`
   gained `chunkSystemPrompt` + `transcript(lines)`; `ProfilePromptSource` delegates to
   `ExtractionPrompts` (single/chunk user messages); only the prose-reduce prompt is LLM-06's.
3. **One `VadEngine`** (`core/platform/vad_engine.dart`): `detect(chunks, modelPath:, cancel:)`
   on the recording timeline + `dispose()`. `FfiVadEngine` (AUD-03) implements it per chunk.
   `TranscribeStep` combines FND-11 (active model id, `waiting(model_missing)`), AUD-03
   (`processing.skip_silence` + installed VAD model; whisper's VAD on the per-chunk path; stored
   `speech_segments`) and STT-04 (windows planned on the stored or VAD `speech_segments`, window
   cache, hallucination guards). Params hashes include model id and the VAD flag.
   `ActiveSttEngine` is a `WindowedSttEngine`, so production takes the long-form path; the
   factory passes `FfiVadEngine` + `FileWindowResultCache`.
4. **Catalog signing:** STT-07's `vv-catalog-dev-2026b` (key_id `8d4a64af2e67eeaf`) is the only
   new pin; AUD-03's different same-named key is dropped. `models.json` = STT-07 Whisper variants +
   AUD-03 `silero-vad-v6.2.0` + existing; `catalog.json(.sig)` rebuilt and re-signed with
   `tools/model-catalog/catalog.py` (private key outside the repo). `vv-catalog-dev-2026a` stays
   pinned.
5. **Vault writing = EXP-05's VaultTarget abstraction.** The production factory passes
   `platformVaultWriterResolver` (SAF / bookmark / app-local; refreshed bookmarks persisted) as
   both `vaultFor` and `vaultResolver`; FND-11's duplicate `vaultWriterFor` is removed. The worker
   reaches the Pigeon host APIs through `BackgroundIsolateBinaryMessenger` (FND-11's
   `RootIsolateToken` in `ProductionEngineSpec`). With a resolver `WriteStep` routes with
   `VaultExporter`; without one the FND-11 single-target write stays (tests).
6. **AUD-08 destination ↔ routing.** The per-recording destination (`recording.destination.<id>`)
   becomes `RoutingInput.chosenTargetId`. PRODUCT-DECISION: an explicit destination wins over the
   routing rules (new `RouteSource.userChoice`); an inactive/deleted target falls back to normal
   routing.
7. **Templates:** `loadNoteRenderer` passes EXP-07's `templates.bindings` as
   `TemplateNoteRenderer.templateOverrides` (custom template bodies were already in the snapshot).
   EXP-07's `previewRecordingsProvider` is renamed `templatePreviewRecordingsProvider` (it clashed
   with PRF-07's provider of the same name).
8. **Model selection:** MDL-03's `ActiveModelKeys` are the keys FND-11's publisher watches
   (`models.active_stt` / `models.active_llm`, test-pinned). `defaultsFor` (LLM-07),
   `selectActiveModels` (FND-11) and `recommendBundle` (APP-01 / MDL-03 "recommended") take the
   STT default from STT-07's `recommendedSttModel` (tier × plan × language; language from the device
   locale via `defaultSttLanguage` until a setting exists), falling back to the old pick when the
   catalog has none of STT-07's variants. Entitlement enforcement stays in the selection's
   `usable()` (LIC-01). `ActiveSttEngine` applies `sttLanguageFor` (`.en` models decode English).
9. **Transcript links:** `transcriptNavigatorProvider` = `PlaybackTranscriptNavigator` — STT-06's
   viewer/editor at `?t=`, scrolled to the segment and playing from it (PRODUCT-DECISION:
   "play from here"); APP-02's read-only lines view stays (`LinesTranscriptNavigator`).
10. **Record button:** APP-01's microphone priming dialog on the first tap; the primed state is
    read when the screen opens so a primed tap still opens the microphone with no await first
    (AUD-08 AC1). A denied start shows APP-01's `PermissionDeniedNotice.microphone()`.
11. **Deletion:** APP-02's `LocalRecordingDeleter` keeps its exported-note step and job
    cancellation, then deletes through SEC-04's `RecordingPurger` (secure_delete, one transaction,
    WAL truncated, files after commit; retried briefly while a cancelled step finishes). With
    APP-02's trigger-maintained FTS5 index, the transcripts purge scope keeps the `title` row of a
    recording that stays.
12. **Encrypted DB + FTS:** no schema clash — SEC-01/SEC-04 add no schema versions, so the chain
    stays v1 → v2 (APP-02 FTS5). `drift_dev make-migrations` produces no change; a new test runs
    APP-02's search on the sqlite3mc-encrypted file (search works, nothing plaintext on disk).
13. **PRF-07 preview LLM:** `bootstrap` backs `llmEngineProvider` with `PreviewLlmEngine` — the
    active installed LLM (FND-11 selection), loaded per preview run and unloaded after, **refused
    while a pipeline job is in an active step** (never two heavy models resident; PRODUCT-DECISION:
    reported as out-of-memory instead of queueing). The dev flavor keeps `VV_DEV_LLM_MODEL`.
14. **Transport exception (STT-06 × SEC-02).** just_audio's `StreamAudioSource` plays through an
    in-process HTTP proxy on 127.0.0.1. `network_security_config.xml` = SEC-02's HTTPS-only,
    system-CA base config + a cleartext `domain-config` for exactly `127.0.0.1` (no subdomains);
    iOS keeps only `NSAllowsLocalNetworking`. `check_egress.sh` accepts exactly these two
    exceptions (XML-parsed; tests prove they never widen to another host or subdomains).
    PRODUCT-DECISION; follow-up: file-based playback would remove both exceptions.
15. **Native:** `vv_vad_create` registers the CPU backend first — in `GGML_BACKEND_DL` builds
    (Android) a process whose first ggml user is the VAD aborted on `GGML_ASSERT(device)`
    (caught by the DL-variant ctest).
16. **Lifecycle host:** EXP-06's outbox recheck runs from FND-11's `didChangeAppLifecycleState`
    on the transition to resumed (a second `AppLifecycleListener` asserted on the lifecycle
    sequences FND-11's host test drives).
17. **CI:** `static` += `check_packages.sh`, `markdownlint.sh`; `native-host` += `size_check.sh`
    and the PRF-09 eval (`fetch-depth: 0`, cached test models, change-detected by `eval.sh`);
    `release.yml` android/ios += `size_check.sh`. `package_audit.json` reviews just_audio,
    re_highlight, re_editor, flutter_markdown_plus; the privacy-audit package table is regenerated.
18. **Bookkeeping:** QA-02's numbers are recorded in ADR-AUD-02 (software AGC stays off) and
    ADR-AUD-03 (skip silence on, ≥ 200 ms padding). EXP's proposed follow-ups are renumbered
    EXP-10/11/12 (EXP-09 is the macOS work). Task statuses are unchanged.

## Consequences
- One code path per concern to verify on devices (engine wiring, VAD, routing, deletion).
- Test-only adjustments: hermetic overrides for AUD-08's pickers and APP-01's onboarding /
  priming state in widget tests that pump the full app or the Record screen; AUD-08/AC1 measures
  tap → microphone open (not the following frame, which flaked > 300 ms under the parallel
  suite); SEC-04 tests follow the trigger-maintained FTS index.
- Open (user): AUD-06 AC1 says CAF on Android, which has no CAF decoder — AC wording decision.
