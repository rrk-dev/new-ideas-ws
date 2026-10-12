# AGENTS.md — VaultVoice (local-first AI voice → Markdown app)

This file is the single source of agent instructions for **Claude Code, Codex and Cursor**.
`CLAUDE.md` imports it; Codex and Cursor read it natively. Keep tool-specific files thin.

## What we are building
A Flutter (iOS + Android) app that records audio, transcribes it on-device with `whisper.cpp`,
extracts structured data with a local LLM via `llama.cpp`, renders Markdown with templates, and
writes it into user-chosen folders (Obsidian/Logseq vaults). **No user content ever leaves the device.**

- Product plan: `complete_master_plan_local_first_ai_voice_intelligence_app.md`
- Engineering tasks (85, incl. 4 phase gates): `tasks/README.md` — one file per task with scope + acceptance criteria.
- Skills (procedures for doing the tasks): `.agents/skills/<skill>/SKILL.md`
  (`.claude/skills` is a symlink to the same folder).

## How to work (every agent, every task)
1. Start with the **`vv-task-workflow`** skill. It tells you how to pick/claim a task, which skills
   to load (each task file lists them on its `**Skills:**` line), and the Definition of Done.
2. Load every skill listed on the task's `**Skills:**` line before writing code.
3. Work only inside the task's scope. If you find missing work, add it to the task's
   `## Follow-ups` section or propose a new task — do not silently expand scope.
4. **Implementers never mark a task `done`.** Hand off with `tasks.py set <ID> review` (requires
   checkable evidence for every acceptance criterion: `[<ID>/ACn]`-tagged tests, device-checklist
   rows, or artifacts). A *different* tool or a human verifies with `vv-task-verify` and sets
   `done`; the script enforces this. Bootstrap order: FND-01 → FND-02 → FND-03 → QA-01.

## Skill catalog (`.agents/skills/`)
| Skill | Use for |
|---|---|
| `vv-task-workflow` | **Always first.** Pick/claim/implement/hand off tasks; `scripts/tasks.py` |
| `vv-task-verify` | Independent verification of a task in `review` (different tool or human) → `done` |
| `vv-decision-records` | Spikes, technology choices, ADRs |
| `vv-flutter-architecture` | Flutter app structure, Riverpod, UI, Pigeon channels |
| `vv-testing` | Test layers, fakes, integration/stress tests, device matrix |
| `vv-local-database` | drift/SQLite schema, migrations, FTS5, encrypted DB (sqlite3mc/SQLCipher), deletion |
| `vv-pipeline-orchestrator` | Job state machine, resume, retry, progress |
| `vv-background-execution` | iOS/Android background, FGS, thermal |
| `vv-native-build` | whisper.cpp/llama.cpp/ggml builds for Android/iOS/host |
| `vv-ffi-bridge` | C ABI bridge + Dart FFI |
| `vv-audio-capture` | Recording, VAD, interruptions, import, recovery |
| `vv-whisper-stt` | Whisper usage, long-form, diarization, transcript UI |
| `vv-llm-inference` | llama.cpp usage, grammars, map-reduce, memory tiers |
| `vv-model-delivery` | Signed catalog, downloader, sideload |
| `vv-extraction-profiles` | Profile spec, prompts, built-in profiles, classification |
| `vv-markdown-vault-export` | Templates, filenames, SAF/bookmarks, routing, outbox |
| `vv-privacy-security` | Egress, logging, encryption, licenses, store privacy, threats |
| `vv-licensing-iap` | Entitlements, StoreKit 2/Play Billing, enterprise, MDM |
| `vv-benchmark-eval` | WER/DER, extraction evals, perf/battery/thermal |
| `vv-ci-release` | CI scripts, signing, crash capture, size, store submission |

Tool notes:
- Codex and Cursor discover `.agents/skills/` natively. Claude Code discovers `.claude/skills/`,
  which is a symlink to `../.agents/skills` — edit skills only under `.agents/skills/`.
- Cursor also scans `.claude/skills/`, so it may list each skill twice (identical content, extra
  context). Prefer the `.agents/skills/...` entry.
- Windows: enable Developer Mode, then clone with `git clone -c core.symlinks=true …`. Existing
  clone: `git config core.symlinks true && git checkout -- .claude/skills`. Otherwise
  `robocopy .agents\skills .claude\skills /MIR` (do not commit the copy). Without this, Claude
  Code silently sees no skills. Use `py -3` instead of `python3` on Windows.
- If a tool doesn't auto-load a skill, open `.agents/skills/<name>/SKILL.md` and follow it.

## Repository layout (target — created by FND-01/FND-06)
```
app/                      Flutter application (package name: vaultvoice)
  lib/core/               cross-cutting: errors, logging, network gateway, platform abstractions
  lib/features/<f>/       data/ domain/ presentation/ per feature
  test/ integration_test/
  pigeons/                Pigeon API definitions (platform channels)
  tool/render_prompt.dart CLI used by the eval harness to render prompts exactly like the app
native/whisper.cpp        git submodule (pinned)
native/llama.cpp          git submodule (pinned)
native/bridge/            vv_bridge.h / .cpp — the ONLY C ABI Dart talks to
native/CMakeLists.txt     superproject (one ggml) + native/build.sh {android|ios|host}
packages/vv_native/       (Dart FFI bindings + plugin build glue; C sources live in native/bridge/)
tools/bench/              STT/LLM/perf benchmarks; tools/bench/eval/ = extraction eval (PRF-09)
tools/ci/                 CI scripts (format, analyze, egress, recording policy, size, eval…)
tools/spikes/             throw-away spike code referenced by ADRs
tools/model-catalog/      manifest generation + signing CLI
tools/licensing/          enterprise license signing CLI (LIC-03)
docs/adr/                 Architecture Decision Records (ADR-<TASK-ID>-<slug>.md)
docs/                     models.md, profile-spec.md, templates.md, markdownlint.json, testing.md,
                          licenses.md, privacy-audit.md, threat-model.md, device-matrix.md,
                          test-plans/stress.md, enterprise-licensing.md, mdm-config.md,
                          crash-triage.md, release-checklist.md
tasks/                    task files (status lives here)
.agents/skills/           skills (canonical)
```

## Non-negotiable rules
- **Privacy:** no analytics/crash/ads SDKs; no network call outside `lib/core/network/` gateway
  and its allowlist (model catalog/CDN; store billing runs inside OS frameworks, not our client). Never log transcript text, LLM output or
  audio file names at INFO or above. See `vv-privacy-security`.
- **Recording ethics (SEC-09, legal requirement):** record only via the standard OS microphone
  APIs, only after an explicit user tap, with a visible indicator. **Never record phone or VoIP
  calls**: stop capture when a call rings/starts and never auto-resume. No call-related
  permissions (`READ_PHONE_STATE`, `READ_CALL_LOG`, `CAPTURE_AUDIO_OUTPUT`…), no call audio
  sources, no CallKit/VoIP modes, no Accessibility/MediaProjection capture, no voiceprints.
  Details: `vv-audio-capture` → "Recording policy".
- **Platforms:** iOS 16+, Android API 26+ (arm64-v8a only). Flutter/Dart pinned via FVM.
- **State:** Riverpod (code-gen). **DB:** SQLite via drift (see ADR-FND-04 once written).
- **Native:** Dart calls only `native/bridge` C functions (incl. VAD and diarization — no direct
  third-party native Dart packages unless an ADR approves an exception). No C++ types across FFI.
  Heavy work runs on native threads or a background isolate — never on the UI isolate.
- **Memory:** never hold STT and LLM models in memory at the same time.
- **Quality gates before any commit** (once `app/` exists — FND-01): `fvm dart format
  --set-exit-if-changed .`, `fvm flutter analyze` (zero issues), `fvm flutter test`. Native
  changes also need the native smoke test. Always: `python3 .agents/skills/vv-task-workflow/scripts/tasks.py validate`.
- **Decisions:** any choice between technologies is recorded as an ADR (`vv-decision-records`).
- **Version-sensitive APIs** (llama.cpp, whisper.cpp, Flutter plugins, Android/iOS policies)
  change often. Verify against the pinned source/headers or official docs before use; never
  rely on memory alone. Record the version you verified against in the code comment or ADR.

## Commands (run from the repo root)
```bash
python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready      # works now
python3 .agents/skills/vv-task-workflow/scripts/tasks.py validate   # works now
# valid once FND-01 lands:
(cd app && fvm flutter pub get)
(cd app && fvm dart format --set-exit-if-changed .)
(cd app && fvm flutter analyze)
(cd app && fvm flutter test)
(cd app && fvm flutter run --flavor dev -t lib/main_dev.dart)
```

## Git conventions
- Branch: `task/<TASK-ID>-<short-slug>` (e.g. `task/FND-04-local-database`). One task per branch.
- Commits: Conventional Commits with task id scope: `feat(FND-04): add drift schema v1`.
- PR title: `[<TASK-ID>] <task title>`; body links the task file and pastes Completion Notes.
