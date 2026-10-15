# QA-01 — Test Strategy & Automated Test Framework

**Workstream:** Quality | **Phase:** 1 | **Size:** M | **Depends on:** FND-02, FND-03 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-testing, vv-ci-release

## Goal
A test pyramid that keeps the pipeline reliable as models/prompts change.

## Scope
- [x] Unit tests (domain, rules engine, templates, sanitization, entitlements) — coverage target ≥ 80% for `lib/**/domain/**` and `lib/core/**`. _(Framework: `app/test/unit/` layout, deterministic Clock/ID/seed helpers. The ≥ 80% gate (FND-03 `check_coverage.py` in `tools/ci/test.sh`) is covered by `[QA-01/AC2]`. Each feature task adds unit tests for its own domain code.)_
- [x] Widget tests for every screen state; golden tests for key screens. _(`goldenTest()` helper; real fonts in `app/test/flutter_test_config.dart`; light + dark × text scale 1.0/2.0; Linux-reference comparator and `tools/ci/update_goldens.sh`; goldens for the Record and Library screens. Screens that later gain real states add their own widget/golden tests.)_
- [~] Integration tests (`integration_test`) for record → transcribe → extract → export using tiny models on device/simulator. deferred → QA-06: scaffold `app/integration_test/e2e_test.dart` (device boot test + skipped tiny-model flow) and sha256-pinned `tools/ci/fetch_test_models.sh` are done. The flow needs the real STT/LLM/export engines and a debug-only model-seeding hook, and none of them exist yet.
- [x] Fake engines (FND-02) for fast pipeline tests in CI without models. _(Reused the FND-02 fakes. Added `SequentialIdGenerator`, `PipelineHarness` with `restart()` for kill/resume, `tokensOf()` and the example `app/test/pipeline/fake_pipeline_test.dart`.)_
- [x] Test fixtures: short audio clips, transcripts, expected Markdown. _(`app/test/fixtures/{transcripts,llm,markdown}/`; `synthWav()` builds deterministic 16 kHz mono clips; real speech (`jfk.wav`) comes via `fetch_test_models.sh`.)_

## Acceptance Criteria
- Acceptance-tag convention (`[<ID>/ACn]`) and device-checklist location documented in `docs/testing.md`; one example tagged test and one example device checklist committed.
- `docs/testing.md` defines layers, ownership and gates; CI enforces coverage threshold.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/QA-01-test-framework · **Date:** 2026-10-12
- **Summary:** `docs/testing.md` covers layers, ownership, gates, the `[<ID>/ACn]` convention for Dart, pytest and ctest, and device checklists at `docs/test-plans/device/<ID>.md`. Also added:
  - Determinism: `lib/core/platform/id_generator.dart` (`IdGenerator` with a UUID-v4 `RandomIdGenerator`, `idGeneratorProvider`) and `app/test/helpers/deterministic.dart` (`kTestSeed`, `kTestEpoch`, `testClock()`, `testIds()`). `fakeEngineOverrides()` now also overrides IDs.
  - Fixtures: `app/test/helpers/fixtures.dart` (fixture loader, `synthWav()`) plus synthetic fixtures in `app/test/fixtures/`.
  - Pipeline tests: `app/test/helpers/pipeline_harness.dart` (`PipelineHarness` with `restart()`) and the example `app/test/pipeline/fake_pipeline_test.dart`.
  - Goldens: `app/test/helpers/golden.dart` and `app/test/flutter_test_config.dart` (Roboto/MaterialIcons from the pinned SDK, both themes, text scale 1.0/2.0, tolerant comparator). Linux is the reference host; on macOS a golden diff is reported as a skip, and `VV_GOLDEN_STRICT=1` makes it fail. Goldens live in `app/test/golden/goldens/` and were generated on Linux with `tools/ci/update_goldens.sh` (podman).
  - On-device scaffold: `app/integration_test/e2e_test.dart`.
  - Test models: `tools/ci/fetch_test_models.sh` + `tools/ci/test-models.lock` (ggml-tiny.en, SmolLM2-135M-Instruct Q8_0, jfk.wav). URLs are pinned to a revision and checked by sha256 into a cache dir outside the repo.
  - Tests of all of the above: `app/test/unit/{id_generator,test_helpers}_test.dart` and `tools/ci/tests/test_test_framework.py`.
  - Example device checklist: `docs/test-plans/device/QA-01.md`.
  - The coverage threshold was already enforced by FND-03 (`tools/ci/test.sh` → `check_coverage.py`, 80%). QA-01 adds a regression test for it rather than a second gate.
- **Acceptance evidence:**
  - AC1: ✅ test: [QA-01/AC1]; artifact: docs/testing.md; artifact: docs/test-plans/device/QA-01.md
  - AC2: ✅ test: [QA-01/AC2]; artifact: docs/testing.md
- **Gate results (macOS host, Flutter 3.47.7):**
  - `fvm dart format --set-exit-if-changed .`: 0 changed.
  - `fvm flutter analyze`: no issues.
  - `fvm flutter test --coverage`: 37 passed, 8 skipped (the goldens skip on macOS by design; all 8 pass on Linux in podman).
  - `check_coverage.py`: 94.9% of 136 gated lines.
  - `check_egress.sh`: OK.
  - `pytest tools/ci/tests`: all QA-01 tests pass. The FND-06 test `test_FND_06_AC1_…` fails in this worktree only because the native submodules are not checked out; it is not touched by QA-01.
- **Decisions:**
  - PRODUCT-DECISION (engineering default): the test LLM is SmolLM2-135M-Instruct Q8_0 (Apache-2.0, 145 MB), the smallest instruct GGUF under the 200 MB rule.
  - Goldens are enforced on Linux only.
  - `fetch_test_models.sh` is not yet wired into a CI job, because nothing consumes the models yet.
- **Follow-ups:** QA-06 (proposed).

## Follow-ups
- **QA-06 (proposed): enable the on-device tiny-model e2e flow.** Add a debug-only model-seeding hook that copies `fetch_test_models.sh` output into the app models dir. Turn on the skipped test in `app/integration_test/e2e_test.dart` once the STT, LLM and export engines exist. Add `tools/ci/device_suite.sh` (vv-ci-release), and wire `fetch_test_models.sh` (cached) into the `native-host` job when its smoke test needs a model. Depends on STT-0x, LLM-0x, EXP-0x, MDL-02.
- The CI runner is x86_64 and the goldens were generated on arm64 Linux. The first CI `test` run must confirm that the diff stays within 0.05%. If it does not, regenerate the goldens from the CI failure images (`app/test/golden/failures/`, or run `update_goldens.sh` on x86_64).


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ docs/testing.md documents [<ID>/ACn], discovery/runners and docs/test-plans/device/<ID>.md. The example fake pipeline asserts generated Markdown, progress, prompt, tokens and output path. Example QA-01 checklist has the required columns/steps and is expressly illustrative, not evidence of a claimed device run.
  - AC2: ✅ Read layer/ownership/gate definitions and CI test.sh wiring. Threshold tests assert 79.9% fails and 80.0% passes with generated/non-domain exclusions; global coverage gate rerun.
- **Adversarial checks:** Lowered the coverage default to 79.9%; [QA-01/AC2] boundary test failed, then passed after git checkout restored check_coverage.py. Shared tests additionally cover model-download hash mismatch, caching, unknown names and refusing a destination inside the repository. No models downloaded for this verification.
- **Skill/rule compliance:** The integration flow is explicitly deferred to QA-06 with rationale; placeholder skipped flow is not presented as an executed acceptance test. Linux reference goldens remain enforced in CI and platform skips are reported. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** none
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify QA-01 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/QA-01-verify.log`.
- **Pending for done:** dependency FND-02 is not done; dependency FND-03 is not done.
