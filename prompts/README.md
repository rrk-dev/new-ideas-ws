# Subagent prompts

One prompt per task group (`tasks/<NN-group>/`), plus an independent verifier. Each prompt is
self-contained: paste it into a fresh Claude Code, Codex or Cursor session opened at the repo root.

| Prompt | Group | Tasks |
|---|---|---|
| [01-foundation.md](01-foundation.md) | Foundation | FND-01…08 (8) |
| [02-audio.md](02-audio.md) | Audio | AUD-01…08 (8) |
| [03-stt.md](03-stt.md) | STT | STT-01…07 (7) |
| [04-llm.md](04-llm.md) | LLM | LLM-01…08 (8) |
| [05-models.md](05-models.md) | Model Delivery | MDL-01…04 (4) |
| [06-profiles.md](06-profiles.md) | Profiles | PRF-01…09 (9) |
| [07-export.md](07-export.md) | Export | EXP-01…08 (8) |
| [08-app-ux.md](08-app-ux.md) | App UX | APP-01…06 (6) |
| [09-licensing.md](09-licensing.md) | Licensing | LIC-01…04 (4) |
| [10-security-privacy.md](10-security-privacy.md) | Security & Privacy | SEC-01…09 (9) |
| [11-quality.md](11-quality.md) | Quality | QA-01…05 (5) |
| [12-release.md](12-release.md) | Release | REL-01…05 (5) |
| [13-milestones.md](13-milestones.md) | Milestones | GATE-01…04 (4) |
| [00-verifier.md](00-verifier.md) | Independent verifier | any task in `review` |

## Start order (groups depend on each other)
Starting all 13 at once would leave most agents blocked. Recommended waves:

| Wave | Run these agents | Why |
|---|---|---|
| 0 — bootstrap | **Foundation** (FND-01 → 02 → 03) + **Quality** (QA-01, QA-05) | Nothing else can reach `done` before CI (FND-03) and the test framework (QA-01) exist. |
| 1 — Phase 1 | Foundation (FND-04/05/06) · **Security** (SEC-09 first, SEC-01 ADR) · **Audio** · **Export** (EXP-03/04) | Recording path, native build, vault access → GATE-01. |
| 2 — Phase 2 | **STT** · **LLM** · **Model Delivery** · **Profiles** (PRF-01/02/09) | On-device AI → GATE-02. |
| 3 — Phase 3 | Profiles (rest) · Export (rest) · **App UX** · Security (rest) | Notes in the vault → GATE-03. |
| 4 — Phase 4 | **Release** · **Licensing** (only if commercial) · Quality (QA-03/04) | Release candidate → GATE-04. |
| Throughout | **Milestones** (prepares gate scripts early) · **Verifier** (whenever tasks reach `review`) | |

Check what's unblocked at any time:
`python3 .agents/skills/vv-task-workflow/scripts/tasks.py ready --workstream "<group>"`

## Rules for running several agents
- **Implementer ≠ verifier.** Alternate tools: e.g. Claude Code implements Audio, Codex verifies it.
  `tasks.py set <ID> done` refuses if the verifier used the same tool.
- **One task per branch** (`task/<ID>-…`); claims are visible through pushed branches, so create
  the git remote first.
- **Shared files** (`pubspec.yaml`, DB schema, `analysis_options.yaml`, Gradle/Xcode config) cause
  merge conflicts: rebase on `main` before every hand-off. DB schema changes go through a migration
  (`vv-local-database`) — never edit another group's tables without a note in their task.
- **Product decisions** flagged in prompts (personal vs commercial scope, Free/Pro tiers, consent
  defaults) are yours; agents will stop and ask.
- Agents report in a fixed format when they stop; collect those reports to plan the next wave.
