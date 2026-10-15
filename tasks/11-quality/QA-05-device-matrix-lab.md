# QA-05 — Device Test Matrix & Lab

**Workstream:** Quality | **Phase:** 1 (procure) – 4 | **Size:** S | **Depends on:** — | **Source:** §2.1, §5 Phase 4
**Status:** review
**Skills:** vv-task-workflow, vv-testing, vv-benchmark-eval

## Goal
Test on the hardware the plan targets, from budget to flagship.

## Scope
- [x] iOS: iPhone 11 (A13, 4 GB), iPhone 13/14 (6 GB), iPhone 15 Pro / 16 (8 GB, A17 Pro/A18); one iPad.
- [x] Android: Snapdragon 8 Gen 3/4 flagship, Snapdragon 7-series mid-range, one MediaTek/Mali device, one 4 GB RAM device, one Samsung (OEM battery management), Pixel (reference).
- [x] Decide cloud device farm (Firebase Test Lab / BrowserStack) usage for non-content smoke tests only — no real user audio uploaded.
- [x] Track device inventory and OS versions.

## Acceptance Criteria
- iOS/Android parity checklist (`docs/parity.md`: every feature × platform, known differences such as iOS Ogg/Opus import) reviewed before beta.
- Matrix documented; devices available to the team by end of Phase 1.

## Completion Notes
- **Agent:** Cursor · **Branch:** task/QA-05-device-matrix-lab · **Date:** 2026-10-12
- **Summary:** Device matrix, lab rules, and inventory table in `docs/device-matrix.md` (eight roles, all `To procure`). Parity checklist in `docs/parity.md`, including iOS rejecting Ogg/Opus. Cloud farms rejected in favor of the physical lab; ADR is Proposed until a person accepts the spend. No unit has been measured.
- **Acceptance evidence:**
  - AC1: ✅ artifact: docs/parity.md
  - AC2: ⏳ device: docs/test-plans/device/QA-05.md
- **Decisions:** ADR-QA-05-device-lab (Proposed — physical lab only)
- **Follow-ups:** QA-06 proposed below; notes on FND-03, FND-06, REL-04, GATE-01

## Follow-ups
- QA-06 (proposed, not filed): a physical Android 8.0 (API 26) arm64 phone if a bug is specific to the OS floor. The required matrix has no API 26 unit, and emulators are not valid for ggml.


## Verification Report
- **Verifier:** Codex · **Implementer:** Cursor · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ Read docs/parity.md: feature/platform inventory includes Ogg/Opus, call guard, vault access, background/GPU differences and an explicit unsatisfied pre-beta sign-off. The review is scheduled before beta, not falsely claimed completed now.
  - AC2: ⏳ docs/device-matrix.md specifies all eight required physical roles, substitutions, inventory fields and lab/privacy policy. Every unit is still To procure; the dated in-lab check remains pending in docs/test-plans/device/QA-05.md. PASS covers the documented matrix with physical availability pending under the batch exception.
- **Adversarial checks:** Removed docs/parity.md temporarily; tasks.py verify QA-05 --run reported AC1: artifact docs/parity.md not found. Restored it with git checkout. This document/procurement task has no tagged executable tests; the mutation checks artifact existence, not hardware availability. Cross-checked role coverage, RAM substitutions, Snapdragon/Samsung overlap and physical-only evidence requirements.
- **Skill/rule compliance:** Completion Notes and ADR identify Cursor as implementer, contrary to the batch attribution to Claude Code; this report preserves the actual author. Codex remains a different tool. Device inventory is not fabricated; Proposed cloud-farm ADR and lab requirements are explicit. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** none
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify QA-05 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/QA-05-verify.log`.
- **Pending for done:** AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/QA-05.md has no PASS result with a date.
