# EXP-05 — Vault Writer & Folder Routing Rules Engine

**Workstream:** Export | **Phase:** 3 | **Size:** M | **Depends on:** EXP-02, EXP-03, EXP-04, LIC-01 | **Source:** §3.1.4, §4.2 (Local File Router), §5 Phase 3, §7 (Multiple folder routing rules — Pro)
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-licensing-iap, vv-local-database, vv-pipeline-orchestrator, vv-testing

## Goal
Route each rendered note to the right destination(s) based on rules.

## Scope
- [x] `VaultTarget` abstraction over SAF (Android) and bookmarks (iOS) + app-local folder.
- [x] Rules: match on profile, tags, keywords, speaker names, auto-classification result → target + sub-path + filename pattern. Ordered, first-match or multi-match.
- [x] Free tier: one target; Pro: multiple targets and rules (LIC-01).
- [x] Optional sidecar outputs: transcript `.md`, audio file copy (m4a) into vault `attachments/`.
- [x] Atomic write (temp file + rename where supported).

## Acceptance Criteria
- Rules engine unit tests cover ordering, multi-match, and fallback target.
- End-to-end: recording → note lands in the rule-selected vault folder on both platforms.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-05-vault-writer-routing · **Date:** 2026-10-14
- **Summary:** Pure routing engine `features/export/domain/routing_engine.dart` (`routeNote`,
  `ruleMatches`, `RoutingPolicy`) + rule model `routing_rule.dart` (matchers `profile_ids`,
  `tags_any`, `keywords_any`, `speakers_any`, `classification_any`; mode `stop`/`continue`, name and
  enabled flag stored in `routing_rules.match` — no schema migration). Per-target options
  (`vault_target_options.dart`: collision mode, filename pattern, transcript/audio sidecars, off by
  default) in settings key `export.target_options`. `VaultExporter` (`data/vault_exporter.dart`)
  writes to every routed target with EXP-02 `planExport` stable identity, persists `exports` rows
  before/after each write (crash-safe, never duplicates), keeps the last confirmed hash on failure,
  and reports `ExportDone` / `ExportNeedsDestination` (no target or revoked) / `ExportFailed`
  (retryable). `VaultWriter` gained `read` (user-edit detection via hash) and `writeBytes`
  (sidecars); SAF/bookmark Pigeon APIs gained `readFile` (Kotlin + Swift implemented, not compiled
  locally). `platformVaultWriterResolver` = the VaultTarget abstraction (SAF / bookmark with
  refreshed-bookmark persistence / app-local). Routing entitlement (LIC-01 `routingRules`,
  `multiTarget`) is mirrored into `export.routing_policy` for the worker isolate
  (`routingPolicyMirrorProvider`, started in `ProcessingServicesHost`); missing value = Free (fail
  closed). UI: editable, reorderable Routing rules screen, rule editor
  (`/settings/routing-rules/:ruleId`), folder options (`/settings/vault-folders/:targetId`), Free
  plan gating via `ensureFeature`; accessibility rows added.
- **Pipeline (minimal, for FND-11):** `PipelineEngines` gained optional `vaultResolver` and
  `audioAttachments`; when `vaultResolver` is set, `defaultSteps` gives `WriteStep` a
  `VaultExporter` and WriteStep delegates to it (`_routedExport`); otherwise the FND-05
  single-target write is unchanged.
- **Acceptance evidence:**
  - AC1: ✅ test: [EXP-05/AC1]
  - AC2: ⏳ test: [EXP-05/AC2]; device: docs/test-plans/device/EXP-05.md
- **Decisions:** PRODUCT-DECISIONs in code: no configured folder ⇒ the job waits
  (`waiting(destination)`, rendered note stays in app storage) instead of silently writing to the
  app-local folder; profile `default_target: ask` treated as unset; a target is used once per note
  (first matching rule wins, exports are keyed recording × target); audio sidecar off by default.
  Default target (fix/export-target): the routing fallback is the default vault target — setting
  `export.default_target` (set when a folder is picked/added or via Settings → Vault folders →
  "Make default"), else the newest active target (it used to be the oldest, which sent notes to a
  stale target). `resolveDefaultTarget` is shared by the exporter and Settings so the "Default"
  badge always matches where notes go. Tests: [EXP-05/AC1] in routing_engine_test,
  vault_exporter_test, settings_screen_test, vault_folder_pick_test.
- **Follow-ups:** EXP-10 (proposed; renumbered in integration wave 3 — EXP-09 is taken by the macOS work): persist PRF-06 classification result so `classification_any`
  applies; EXP-11 (proposed): `AudioAttachmentSource` implementation (m4a/AAC encode of the WAV
  chunks) and per-target `audio_link` rendering; FND-11: pass `platformVaultWriterResolver` in the
  real engines factory + `BackgroundIsolateBinaryMessenger` in the pipeline isolate.
- Codex review 2026-10-15 (open): audio export silently succeeds without attachment when no audio source is wired (needs encoder/source, product decision on failure reporting)
- Codex review 2026-10-15 (open): `classifiedProfileId` never populated (export_request_builder.dart:61); persist classification result (schema/migration)
