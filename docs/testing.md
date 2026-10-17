# Testing

How Lumen is tested: which layers exist, who owns them, which gates block a merge,
and how every acceptance criterion gets checkable evidence. The rules behind this page
are in `.agents/skills/vv-testing/SKILL.md`. Task workflow and verification are in
`vv-task-workflow` and `vv-task-verify`.

## Layers

| Layer | Location | What it covers | Runs | Tools |
|---|---|---|---|---|
| Unit | `app/test/unit/` | domain logic, rules engine, templates, sanitisers, entitlements, state machines, `lib/core/**` | every PR (`test`) | `flutter_test`, `mocktail` |
| Widget | `app/test/widget/` | every screen state: loading, empty, error, content, permission denied | every PR (`test`) | `flutter_test` + fakes |
| Golden | `app/test/golden/` (images in `goldens/`) | key screens, light + dark, text scale 1.0 + 2.0 | every PR (`test`), enforced on Linux | `goldenTest()` in `app/test/helpers/golden.dart` |
| DB / migration | `app/test/db/` (generated migration tests in `app/test/db/migrations/`) | drift schema, DAOs, FTS, every migration step | every PR (`test`) | drift `NativeDatabase.memory()`, `drift_dev make-migrations` |
| Pipeline (fakes) | `app/test/pipeline/` | job flow transcribe → extract → render → write, progress, cancel, failures, kill/resume | every PR (`test`) | `PipelineHarness` + `FakeSttEngine`/`FakeLlmEngine`/`FakeVaultWriter` |
| Prompt snapshots | `app/test/golden_prompts/` | rendered prompts per profile (PRF-02) | every PR (`test`) | `flutter_test` |
| Native bridge smoke | `packages/vv_native/test/` (Dart FFI on host) + ctest in `native/` | C ABI loads, versions, smoke calls | every PR (`native-host`) | ctest, `dart test` |
| CI gate tests | `tools/ci/tests/` | the CI scripts themselves fail when they should | every PR (`task-gate`) | pytest |
| On-device integration | `app/integration_test/` | real tiny models on a device/simulator, end to end | device lab, nightly + before each phase gate | `integration_test`, `flutter test -d` |
| Benchmarks / evals | `tools/bench/` | WER/RTF, DER, extraction quality, perf/battery/thermal | nightly / manual | `vv-benchmark-eval` |

The CI job names are those in `.github/workflows/ci.yml` (`docs/ci.md`).

## Ownership

| What | Owner |
|---|---|
| Tests for new or changed code (unit, widget, golden, DB, pipeline) | the implementer of that task, in the same branch. Tests are part of the task, not a follow-up. A bug fix starts with a failing test |
| Acceptance tests `[<ID>/ACn]` and device-checklist rows | the implementer writes them. A different tool or a human verifies them (`vv-task-verify`) |
| This document, shared fakes/fixtures/helpers, golden config, `fetch_test_models.sh` | Quality (QA-01) |
| Fakes contract (`app/test/fakes/`) | the engine interface owner (FND-02) together with Quality. Whoever changes an interface updates its fake |
| `PipelineHarness` extensions (DB file, job queue) | the pipeline orchestrator task (FND-05) |
| Native smoke tests | native build/bridge tasks (FND-06 and the STT/LLM bridge tasks) |
| Device matrix and device runs | Quality (QA-05 matrix, `docs/device-matrix.md`). Testers fill Result/Date |
| Stress and edge-case plan | Quality (QA-04, `docs/test-plans/stress.md`) |
| Benchmarks and evals | Quality (QA-02, QA-03) and Prompts (PRF-09) |

## Gates

Before every push, in `app/`:

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze                 # zero issues
fvm flutter test --coverage
python3 ../tools/ci/check_coverage.py coverage/lcov.info
```

At the repo root:

```bash
python3 -m pytest tools/ci/tests -q
python3 .agents/skills/vv-task-workflow/scripts/tasks.py validate
```

Native changes also need `bash tools/ci/native_host.sh`.

What CI blocks on (every PR):

| Gate | Script | Threshold |
|---|---|---|
| Format | `tools/ci/format.sh` | no diff |
| Analyze | `tools/ci/analyze.sh` | zero issues (`flutter analyze` + `dart analyze` for riverpod_lint) |
| Tests + coverage | `tools/ci/test.sh` → `fvm flutter test --coverage`, then `check_coverage.py` | all tests pass; **≥ 80% lines** over `lib/core/**` and `lib/**/domain/**`, generated `*.g.dart`/`*.freezed.dart` excluded |
| Goldens | part of `test.sh` | ≤ 0.05% differing pixels on Linux |
| Codegen, egress, recording policy | `check_codegen.sh`, `check_egress.sh`, `run_slot.sh check_recording_policy.sh` | no diff / no violation |
| Task gate | `pytest tools/ci/tests`, `tasks.py verify --all-done --run` | every `done` task keeps its tagged tests (re-run), artifacts, PASS rows and Verification Report |

Never lower the 80% threshold to get a branch green. Add tests.

## Acceptance tags `[<ID>/ACn]`

Every acceptance criterion needs evidence that a machine can check. `ACn` is the n-th
bullet under the task's `## Acceptance Criteria` (counting from 1).

- **Automatable criterion:** at least one test whose **name** contains `[<ID>/ACn]`, for
  example `[QA-01/AC1]`. The test must assert the criterion's number, threshold or failure
  path. A test that cannot fail is rejected (the verifier mutates the code and expects
  a red test).
  - Dart: `test('[<ID>/ACn] …', …)` or `testWidgets('[<ID>/ACn] …', …)`.
    `tasks.py verify <ID> --run` runs each file that contains the tag with
    `fvm flutter test <file> --plain-name '[<ID>/ACn]'`. So put the tag only in test
    names. A tag mentioned only in a comment makes that run find no test and fail.
  - pytest: the function name contains `<ID>_ACn` with `-` → `_` (for example
    `test_QA_01_AC2_…`), and the docstring carries `[<ID>/ACn]`. `--run` uses `-k`.
  - C/C++ (ctest): put the tag in the test name or a comment, for example
    `TEST(Bridge, FND06_AC2)` with `// [<ID>/ACn]`. `--run` reports these and the
    native-host CI job runs them.
  - Integration tests under `app/integration_test/` are found but not run by `--run`.
    They need a device, so pair them with a device-checklist row.
- **Device-only criterion:** a row in **`docs/test-plans/device/<ID>.md`** (see below).
- **Document or decision criterion:** the artifact path (ADR, doc, report).

Completion Notes cite the evidence exactly:
`- AC1: ✅ test: [<ID>/AC1]`, `- AC2: ⏳ device: docs/test-plans/device/<ID>.md`,
`- AC3: ✅ artifact: docs/adr/ADR-<ID>-<slug>.md`. Check before hand-off with
`python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify <ID> --run`.

Tagged tests are permanent regression tests. `tasks.py verify --all-done --run` runs in
CI, so renaming or deleting a tag breaks the build. Change a tag only together with an
approved change to the criterion.

**Example tagged test:** `app/test/pipeline/fake_pipeline_test.dart`
(`[QA-01/AC1] example tagged test: …`). The pytest examples are in
`tools/ci/tests/test_test_framework.py`.

## Device checklists

Location: **`docs/test-plans/device/<ID>.md`**, one file per task, copied from
`.agents/skills/vv-task-verify/assets/device-checklist.md`. One table row per device-only
criterion (and per device/OS when the criterion names several):

| Column | Filled by |
|---|---|
| AC (`[<ID>/ACn]`), numbered Steps, Expected | implementer |
| Device (a `docs/device-matrix.md` ID such as VV-IOS-11), OS | implementer proposes, tester confirms |
| Result (`PASS`/`FAIL`), Date (`YYYY-MM-DD`), Tester | whoever actually ran it, never earlier |

`tasks.py` accepts a row for `done` only when Result is `PASS` and Date is a date. Put
logs and screenshots under `docs/test-plans/device/evidence/<ID>/`. Until a device run
happens, the evidence line stays `⏳ device: …` and the task can still go to `review`.

**Example device checklist:** `docs/test-plans/device/QA-01.md`.

## Test layout and shared helpers

```
app/
  dart_test.yaml               test tags (golden)
  test/
    flutter_test_config.dart   per-file setup: real fonts + golden comparator
    fakes/                     one fake per engine interface (FND-02) + SequentialIdGenerator
    helpers/
      test_container.dart      fakeEngineOverrides(), createContainer()
      deterministic.dart       kTestSeed, kTestEpoch, seededRandom(), testClock(), testIds()
      fixtures.dart            Fixtures.readString/readJson/transcript(), synthWav()
      pipeline_harness.dart    PipelineHarness (fakes + temp dir + restart), tokensOf()
      golden.dart              goldenTest(), TolerantGoldenComparator, loadTestFonts()
    fixtures/                  transcripts/, llm/, markdown/ (synthetic, each < 1 MB)
    unit/ widget/ golden/ db/ pipeline/ golden_prompts/
  integration_test/            on-device tests (e2e_test.dart, native_bridge_test.dart)
tools/ci/
  fetch_test_models.sh         sha256-pinned tiny models → cache dir
  test-models.lock             name, sha256, size, pinned URL
  update_goldens.sh            regenerate goldens on Linux (podman on macOS)
```

### Determinism

- **Time:** read time only through `clockProvider` (`Clock`). Tests use `FakeClock`
  (`testClock()` starts at `kTestEpoch` and moves only on `advance`).
- **IDs:** create IDs only through `idGeneratorProvider` (`IdGenerator`, real impl
  `RandomIdGenerator` = UUID v4). Tests get `id-0001`, `id-0002`, … from
  `SequentialIdGenerator`. `fakeEngineOverrides()` installs both.
- **Randomness:** inject `Random`. Tests use `seededRandom()` (`kTestSeed` = 42). LLM
  tests use the seed and temperature 0.
- No real network, no real models, no wall-clock sleeps in `app/test/`. Fakes simulate
  time with `perChunk`/`perToken` delays.

### Fixtures

`Fixtures` reads from `app/test/fixtures/` (tests run with `app/` as the working
directory). Transcripts are JSON `{segments: [{start_ms, end_ms, text}]}`, loaded by
`Fixtures.transcript(name)` straight into `FakeSttEngine(segments: …)`. Expected Markdown
lives in `fixtures/markdown/`. Audio is generated with `synthWav()` (deterministic
16 kHz mono PCM16, sine or silence), so no binary clips are committed. Real speech for
device tests comes from `fetch_test_models.sh` (`jfk.wav`). All fixtures are synthetic
or public domain. **Never commit personal recordings.**

### Pipeline tests with fakes

`PipelineHarness` wires every engine provider to a fake, plus a deterministic clock and
IDs and a temp `workDir`. `harness.restart()` disposes the `ProviderContainer` and builds
a new one against the same `workDir` and fakes. That is the "app killed mid-job,
relaunched" scenario, so kill/resume tests can reopen the same DB file
(`harness.file('vv.db')`) once FND-04/05 add a database override through `overrides:`.
Script failures with `fake.failWith(Failure)`, cancellation with a `CancelToken`, and
streaming with `tokensOf(text)` for `FakeLlmEngine`. See
`app/test/pipeline/fake_pipeline_test.dart`.

### Golden tests

- `flutter_test_config.dart` loads **Roboto and MaterialIcons from the pinned Flutter
  SDK** (`bin/cache/artifacts/material_fonts`) for every test file, so goldens show real
  text. It fails loudly if the fonts are missing.
- `goldenTest('Screen', fileName: 'x', builder: …)` renders a 390×844 surface in
  **both themes** (`AppTheme.light`/`dark`) at **text scale 1.0 and 2.0** and compares
  `goldens/x_<light|dark>_x<1.0|2.0>.png`. The tests carry the `golden` tag
  (`--tags golden` / `--exclude-tags golden`).
- **Linux is the reference host.** macOS rasterises glyph edges differently (about 0.6%
  of pixels on a simple screen), so goldens are generated and enforced on Linux, the CI
  `test` job. On Linux a diff above 0.05% of pixels fails. On macOS/Windows a larger diff
  marks the test *skipped* with the diff percentage instead of failing. Set
  `VV_GOLDEN_STRICT=1` to make it fail there too.
- Regenerate after an intended UI change with `bash tools/ci/update_goldens.sh`. It runs
  the `.fvmrc` Flutter version in a podman Linux container on macOS, or directly on Linux.
  Review the new PNGs in the diff before committing them.

## On-device integration

`app/integration_test/e2e_test.dart` is the device suite scaffold. It boots the app on a
device, and the tiny-model flow (seed models → import `jfk.wav` → transcript keywords →
Meeting extraction is schema-valid JSON → export file exists with parseable
front-matter) is in place but skipped until the real engines and a debug-only
model-seeding hook exist. Run:

```bash
bash tools/ci/fetch_test_models.sh            # prints VV_TEST_MODELS_DIR=…
cd app && fvm flutter test integration_test/e2e_test.dart --flavor dev -d <device-id>
```

### Test models

`tools/ci/fetch_test_models.sh [--dest DIR] [NAME…]` downloads the entries in
`tools/ci/test-models.lock` (`ggml-tiny.en.bin`, `SmolLM2-135M-Instruct-Q8_0.gguf`,
`jfk.wav`). Each URL is pinned to an immutable revision and each file is checked against
its sha256. The cache is `$VV_TEST_MODELS_DIR`, else
`~/.cache/vaultvoice/test-models`. Cached files that verify are not downloaded again. A
mismatch deletes the download and exits 1. The script refuses a destination inside the
repo, and `*.gguf`/`ggml-*.bin` are gitignored, so **models are never committed**. To add
a model, append a line with its sha256 and size, and keep each test model ≤ 200 MB.
