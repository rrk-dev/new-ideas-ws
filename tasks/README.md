# VaultVoice — Engineering Task Breakdown

Derived from `../complete_master_plan_local_first_ai_voice_intelligence_app.md`.
Scope: **engineering only** (marketing, pricing strategy and business tasks excluded). Includes tasks for gaps the master plan does not cover but its intent requires — marked `Source: Gap` in each file.

**How to work a task (any agent: Claude Code, Codex, Cursor):** follow `AGENTS.md` and the
`vv-task-workflow` skill. Each task file has a `**Status:**` line (`todo | in-progress | blocked |
review | done`) and a `**Skills:**` line listing the skills to load. Find unblocked work with
`python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready`; check consistency with `… validate`.

**Sizes:** S ≤ 2 days · M 3–5 days · L 1–2 weeks · XL > 2 weeks
**Phases (from §5):** 1 Foundation & Audio (W1–3) · 2 STT & LLM (W4–7) · 3 Profiles & Markdown (W8–10) · 4 Polish, Testing & Launch (W11–12) · 4+ post-launch / Enterprise

## How we know a task really works (verification)
1. **Acceptance tags** — every automatable criterion has a test named `[<ID>/ACn]`; device-only
   criteria have a row in `docs/test-plans/device/<ID>.md`; decisions have an artifact (ADR/report).
2. **Automated gates** — CI (FND-03) runs format, analyze, all tests, native smoke, egress and
   recording-policy checks, and `tasks.py verify --all-done --run` on every PR, so every finished
   task's acceptance tests become permanent regression tests.
3. **Independent verifier** — the implementer can only move a task to `review`; a *different*
   tool or a human runs the `vv-task-verify` skill (fresh checkout, re-run, adversarial checks,
   Verification Report) and only then can `tasks.py set <ID> done` succeed.
4. **Device evidence** — device rows count only with `PASS` + date + tester.
5. **Phase gates** — GATE-01…04 re-test each phase end to end on real devices.
6. **Bootstrap first** — FND-01 → FND-02 → FND-03 → QA-01 (+ QA-05): nothing else can be `done` before CI and the test framework exist.

## Task Index (85 tasks)

### 01 — Foundation
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [FND-01](01-foundation/FND-01-flutter-repo-init.md) | Flutter repo init & code standards | 1 | S | Plan |
| [FND-02](01-foundation/FND-02-app-architecture-riverpod.md) | App architecture skeleton (Riverpod) | 1 | M | Plan |
| [FND-03](01-foundation/FND-03-ci-pipeline.md) | CI pipeline | 1 | M | Gap |
| [FND-04](01-foundation/FND-04-local-database.md) | Local database (decision, schema, migrations) | 1 | M | Plan |
| [FND-05](01-foundation/FND-05-processing-pipeline-orchestrator.md) | Processing pipeline orchestrator | 1–2 | L | Gap |
| [FND-06](01-foundation/FND-06-native-build-infrastructure.md) | Native C/C++ build infrastructure | 1 | M | Plan |
| [FND-07](01-foundation/FND-07-local-logging-diagnostics.md) | Local-only logging & diagnostics | 1 | S | Gap |
| [FND-08](01-foundation/FND-08-background-processing-guardrails.md) | Background processing guardrails | 4 | L | Plan |
| [FND-11](01-foundation/FND-11-production-engine-wiring.md) | Production engine wiring | 2–3 | L | Gap |

### 02 — Audio
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [AUD-01](02-audio/AUD-01-recording-service.md) | Core recording service (16 kHz WAV) | 1 | M | Plan |
| [AUD-02](02-audio/AUD-02-auto-gain-level-metering.md) | Auto-gain & level metering | 1 | S | Plan |
| [AUD-03](02-audio/AUD-03-silence-detection-vad.md) | Silence detection / VAD | 1–2 | M | Plan |
| [AUD-04](02-audio/AUD-04-ios-background-recording.md) | iOS background recording & interruptions | 1 | M | Plan |
| [AUD-05](02-audio/AUD-05-android-background-recording.md) | Android foreground-service recording | 1 | M | Plan |
| [AUD-06](02-audio/AUD-06-audio-import-conversion.md) | Audio file import & conversion | 2 | M | Gap |
| [AUD-07](02-audio/AUD-07-recording-crash-recovery.md) | In-progress recording crash recovery | 1 | S | Gap |
| [AUD-08](02-audio/AUD-08-recording-ui.md) | Recording screen UI | 1 | M | Plan |

### 03 — Speech-to-Text
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [STT-01](03-stt/STT-01-whisper-ios-build-metal.md) | whisper.cpp iOS (Metal/Core ML) | 2 | M | Plan |
| [STT-02](03-stt/STT-02-whisper-android-build.md) | whisper.cpp Android (NDK/Vulkan) | 2 | M | Plan |
| [STT-03](03-stt/STT-03-whisper-dart-ffi-binding.md) | Whisper Dart FFI binding & engine | 2 | M | Plan |
| [STT-04](03-stt/STT-04-long-form-chunked-transcription.md) | Long-form chunked transcription | 2 | L | Plan |
| [STT-05](03-stt/STT-05-speaker-diarization.md) | On-device speaker diarization | 2–3 | L | Gap |
| [STT-06](03-stt/STT-06-transcript-viewer-editor.md) | Transcript viewer & editor | 2–3 | M | Gap |
| [STT-07](03-stt/STT-07-stt-model-variants-language.md) | STT model variants & language | 2 | S | Plan |

### 04 — LLM
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [LLM-01](04-llm/LLM-01-runtime-selection-spike.md) | Runtime selection spike | 2 | M | Plan |
| [LLM-02](04-llm/LLM-02-llama-ios-build-metal.md) | llama.cpp iOS (Metal) | 2 | M | Plan |
| [LLM-03](04-llm/LLM-03-llama-android-build.md) | llama.cpp Android | 2 | M | Plan |
| [LLM-04](04-llm/LLM-04-llm-dart-ffi-engine.md) | LLM Dart FFI engine | 2 | L | Plan |
| [LLM-05](04-llm/LLM-05-structured-output-grammar.md) | Structured output (constrained decoding) | 2–3 | M | Gap |
| [LLM-06](04-llm/LLM-06-long-transcript-map-reduce.md) | Long-transcript map-reduce | 2–3 | L | Gap |
| [LLM-07](04-llm/LLM-07-memory-management-device-tiering.md) | Memory management & device tiering | 2 | M | Gap |
| [LLM-08](04-llm/LLM-08-default-model-evaluation.md) | Default model evaluation | 2–3 | M | Plan |

### 05 — Model Delivery
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [MDL-01](05-models/MDL-01-model-catalog-hosting.md) | Model catalog manifest & hosting | 2 | M | Plan + Gap |
| [MDL-02](05-models/MDL-02-model-downloader.md) | Resumable model downloader | 2 | M | Plan |
| [MDL-03](05-models/MDL-03-model-management-ui.md) | Model management screen | 3 | S | Gap |
| [MDL-04](05-models/MDL-04-offline-model-sideload.md) | Offline / air-gapped model import | 3–4 | S | Gap |

### 06 — Extraction Profiles
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [PRF-01](06-profiles/PRF-01-profile-data-model.md) | Profile data model & versioning | 2 | M | Plan |
| [PRF-02](06-profiles/PRF-02-system-prompt-builder.md) | System prompt builder | 2 | M | Plan |
| [PRF-03](06-profiles/PRF-03-meeting-action-items-profile.md) | Meeting Action Items profile | 3 | M | Plan |
| [PRF-04](06-profiles/PRF-04-warranty-receipt-profile.md) | Warranty & Receipt profile | 3 | S | Plan |
| [PRF-05](06-profiles/PRF-05-engineering-brainstorm-profile.md) | Engineering / Brainstorm profile | 3 | S | Plan |
| [PRF-06](06-profiles/PRF-06-auto-profile-context-routing.md) | Auto profile classification | 3 | M | Plan |
| [PRF-07](06-profiles/PRF-07-custom-profile-editor.md) | Custom profile editor (Pro) | 3 | L | Plan |
| [PRF-08](06-profiles/PRF-08-profile-import-export.md) | Profile/template import & export | 3–4 | S | Plan + Gap |
| [PRF-09](06-profiles/PRF-09-extraction-eval-harness.md) | Extraction quality eval harness | 2–3 | L | Gap |

### 07 — Markdown Export & Vault
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [EXP-01](07-export/EXP-01-markdown-template-engine.md) | Markdown template engine | 3 | M | Plan |
| [EXP-02](07-export/EXP-02-filename-templates.md) | Filename templates & collisions | 3 | S | Plan |
| [EXP-03](07-export/EXP-03-android-saf-folder-access.md) | Android SAF folder access | 1 | M | Plan |
| [EXP-04](07-export/EXP-04-ios-security-scoped-bookmarks.md) | iOS security-scoped bookmarks | 1 | M | Plan |
| [EXP-05](07-export/EXP-05-vault-writer-routing-rules.md) | Vault writer & routing rules | 3 | M | Plan |
| [EXP-06](07-export/EXP-06-write-failure-outbox.md) | Write failure handling & outbox | 3 | S | Gap |
| [EXP-07](07-export/EXP-07-template-editor-preview.md) | Template editor with preview (Pro) | 3 | M | Plan |
| [EXP-08](07-export/EXP-08-share-and-alternate-outputs.md) | Share sheet & Logseq/plain outputs | 3–4 | S | Gap |

### 08 — App UX
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [APP-01](08-app-ux/APP-01-onboarding-permissions.md) | Onboarding & permissions | 2–4 | M | Gap |
| [APP-02](08-app-ux/APP-02-library-search.md) | Library & full-text search | 3 | M | Gap |
| [APP-03](08-app-ux/APP-03-settings.md) | Settings screen | 3–4 | S | Gap |
| [APP-04](08-app-ux/APP-04-processing-status-notifications.md) | Processing status & notifications | 2–3 | S | Gap |
| [APP-05](08-app-ux/APP-05-result-review-before-export.md) | Result review before export | 3 | M | Gap |
| [APP-06](08-app-ux/APP-06-accessibility-localization.md) | Accessibility & localization | 4 | S | Gap |

### 09 — Licensing
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [LIC-01](09-licensing/LIC-01-entitlements-feature-gating.md) | Entitlements & feature gating | 2–3 | S | Plan |
| [LIC-02](09-licensing/LIC-02-in-app-purchases.md) | In-app purchases + offline entitlement | 3–4 | M | Plan + Gap |
| [LIC-03](09-licensing/LIC-03-enterprise-offline-license.md) | Enterprise offline license keys | 4+ | L | Plan + Gap |
| [LIC-04](09-licensing/LIC-04-enterprise-managed-configuration.md) | Enterprise MDM configuration | 4+ | M | Gap |

### 10 — Security & Privacy
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [SEC-01](10-security-privacy/SEC-01-encryption-at-rest.md) | Encryption at rest | 2–3 | M | Gap |
| [SEC-02](10-security-privacy/SEC-02-network-egress-guarantee.md) | Network egress guarantee | 2–4 | M | Gap |
| [SEC-03](10-security-privacy/SEC-03-app-lock-biometrics.md) | App lock (biometric) | 4 | S | Gap |
| [SEC-04](10-security-privacy/SEC-04-data-retention-secure-deletion.md) | Data retention & secure deletion | 3 | S | Gap |
| [SEC-05](10-security-privacy/SEC-05-model-and-oss-license-compliance.md) | Model & OSS license compliance | 2–4 | S | Gap |
| [SEC-06](10-security-privacy/SEC-06-store-privacy-compliance.md) | Store privacy & policy compliance | 4 | S | Plan + Gap |
| [SEC-07](10-security-privacy/SEC-07-recording-consent-features.md) | Recording consent features | 3–4 | S | Gap |
| [SEC-08](10-security-privacy/SEC-08-threat-model-security-review.md) | Threat model & security review | 2/4 | M | Gap |
| [SEC-09](10-security-privacy/SEC-09-recording-safeguards-no-call-capture.md) | Recording safeguards: user-started only, never record calls | 1 | M | Requirement |

### 11 — Quality
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [QA-01](11-quality/QA-01-test-strategy.md) | Test strategy & framework | 1 | M | Gap |
| [QA-02](11-quality/QA-02-stt-benchmark-corpus.md) | STT benchmark corpus & WER harness | 2 | M | Plan |
| [QA-03](11-quality/QA-03-performance-battery-thermal.md) | Performance, battery & thermal | 2 & 4 | M | Plan |
| [QA-04](11-quality/QA-04-stress-edge-case-testing.md) | Stress & edge-case testing | 4 | M | Plan |
| [QA-05](11-quality/QA-05-device-matrix-lab.md) | Device matrix & lab | 1–4 | S | Plan |

### 12 — Release
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [REL-01](12-release/REL-01-release-build-pipeline.md) | Release build & signing pipeline | 4 | M | Plan |
| [REL-02](12-release/REL-02-private-crash-reporting.md) | Privacy-preserving crash reporting | 4 | S | Gap |
| [REL-03](12-release/REL-03-app-size-optimization.md) | App binary size optimization | 4 | S | Plan |
| [REL-04](12-release/REL-04-beta-program.md) | Beta program | 3–4 | S | Gap |
| [REL-05](12-release/REL-05-store-listing-technical-assets.md) | Store listing technical assets | 4 | S | Plan |

### 13 — Milestones (phase gates)
| ID | Task | Phase | Size | Source |
|---|---|---|---|---|
| [GATE-01](13-milestones/GATE-01-phase1-foundation-recording.md) | Phase 1 gate: foundation, CI & safe recording | 1 | M | Verification |
| [GATE-02](13-milestones/GATE-02-phase2-on-device-ai.md) | Phase 2 gate: on-device transcription & extraction | 2 | M | Verification |
| [GATE-03](13-milestones/GATE-03-phase3-notes-in-vault.md) | Phase 3 gate: full pipeline to the vault | 3 | M | Verification |
| [GATE-04](13-milestones/GATE-04-release-candidate.md) | Phase 4 gate: release candidate | 4 | M | Verification |

## Critical Path

```
FND-01 → FND-06 → STT-01/02 → STT-03 → STT-04 ─┐
                └→ LLM-01 → LLM-02/03 → LLM-04 → LLM-05 → LLM-06 ─┤
FND-02 → FND-04 → FND-05 ──────────────────────────────────────────┤
                                     PRF-01 → PRF-02 → PRF-03 ─────┤
EXP-03/04 → EXP-01 → EXP-02 → EXP-05 ──────────────────────────────┴→ end-to-end MVP
                                                                       → QA-03/04 → REL-01 → REL-05
```

**MVP slice (first end-to-end demo):** FND-01, 02, 04, 05, 06 · AUD-01 · SEC-09 · STT-01/02, 03 · LLM-01–05 · MDL-01, 02 · PRF-01–03 · EXP-01–05.

## Open Decisions (owner: tech lead)
| Decision | Task | Recommendation |
|---|---|---|
| Isar vs SQLite | FND-04 | Decided: ADR-FND-04 (Proposed) — SQLite via `drift` (FTS5 search, encryption via sqlite3mc or SQLCipher build hooks, active maintenance) |
| llama.cpp vs ExecuTorch vs MLC-LLM | LLM-01 | Decided: ADR-LLM-01 (Proposed — host-measured, device rows pending) — llama.cpp (shared ggml with whisper.cpp, GGUF, GBNF grammars); re-open if LLM-02/03 device targets miss by > 1.5× |
| Default LLM per tier | LLM-08 | Decide from PRF-09 eval; expect 1B-class for Low tier, 3B for High |
| Core ML encoder for Whisper on iOS | STT-01 | Proposed: ADR-STT-01 (Metal-only for v1, Core ML one flag away; device benchmark pending) |
| Diarization approach | STT-05 | Spike sherpa-onnx first |
| Mustache vs Handlebars | EXP-01 | Decided: ADR-EXP-01 (Proposed) — Mustache (`mustache_template` 2.0.5, strict) + 15 custom lambdas |
| Model hosting | MDL-01 | Proposed: ADR-MDL-01 — own CDN primary + Ed25519-signed catalog, HF pinned-revision mirror; CDN provider/domain + production key are owner decisions |
| Play purchase verification without a server | LIC-02 | Proposed: [ADR-LIC-02](../docs/adr/ADR-LIC-02-store-verification.md), local verification with bounded Play lease; device evidence pending |
| Enterprise seat enforcement model | LIC-03 | Needs design review |
| Free vs Pro for Warranty / Engineering profiles | LIC-01 | Product decision (§7 is ambiguous) |
| Final product name (OmniScribe vs VaultVoice) | FND-01 | Keep behind a constant until decided |
| Native packaging & Android CPU variants (static vs `GGML_BACKEND_DL`) | FND-06 | Static single `vv_native` + dotprod build if all matrix devices support it |
| VAD engine | AUD-03 | Decided: ADR-AUD-03 (Proposed) — whisper.cpp built-in Silero VAD via `vv_vad_*` (no new runtime); speed numbers from QA-02 |
| File encryption: OS-only vs app-level `vvenc` | SEC-01 (Phase-1 ADR) | Decided: ADR-SEC-01 (Proposed) — OS file encryption (iOS `completeUntilFirstUserAuthentication`, Android CE storage) + sqlite3mc-encrypted DB for v1; `vvenc` → SEC-10 if the strict audio reading is required |
| Crash capture library | REL-02 | Decided: ADR-REL-02 (Proposed) — own async-signal-safe handler in the bridge (`vv_crash.c`), OS/store reports as baseline, no upload endpoint |
| Can users disable per-recording consent confirmation? | SEC-07 | Product/legal decision |
| Recording policy (call capture forbidden, user-tap start) | SEC-09 | Fixed requirement — ADR documents enforcement |
| Cloud device farm (Firebase Test Lab / BrowserStack) | QA-05 | Proposed: physical lab only, no cloud farm (ADR-QA-05). Human accepts or rejects |
| `small.en` Whisper in Free tier? | LIC-01 | Product decision (§7 says Free gets small/tiny) |

## Schedule Risk
The master plan targets 12 weeks. This breakdown (85 tasks incl. 4 phase gates, several L-sized gaps: pipeline orchestrator, diarization, map-reduce extraction, eval harness, enterprise licensing) sums to roughly **56–61 engineer-weeks** (27 S ≈ 1.5 d, 45 M ≈ 4 d, 9 L ≈ 7.5 d). Hitting 12 calendar weeks needs a team of ~5 engineers working in parallel (native/AI, audio/platform, Flutter UI, export/licensing, QA). With a smaller team, keep the 12-week target for a Free + Pro MVP and move diarization (STT-05), the custom profile editor (PRF-07) and Enterprise (LIC-03/04, PRF-08 signing) to v1.1.
