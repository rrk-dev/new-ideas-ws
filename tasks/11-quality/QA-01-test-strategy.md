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
