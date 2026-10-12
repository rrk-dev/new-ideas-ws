---
name: vv-testing
description: "Test strategy and test-writing rules: unit, widget, golden, drift migration, pipeline tests with fake engines, on-device integration_test, native smoke tests, stress/edge-case plans, device matrix. Use whenever code is added or changed."
---

# Testing VaultVoice

## Pyramid
| Layer | Location | Runs in CI | Tools |
|---|---|---|---|
| Unit (domain, rules, templates, sanitizers, entitlements, state machines) | `app/test/unit/` | ✅ | `test`, `mocktail` |
| Widget + golden | `app/test/widget/`, `app/test/golden/` | ✅ | `flutter_test`, `alchemist` or built-in goldens |
| DB / migration | `app/test/db/` (generated migration tests in `app/test/db/migrations/`) | ✅ | drift `NativeDatabase.memory()`, `drift_dev make-migrations` |
| Pipeline with fakes | `app/test/pipeline/` | ✅ | `FakeSttEngine`, `FakeLlmEngine`, `FakeVaultWriter` |
| Native bridge smoke | `packages/vv_native/test/native/` (C) + Dart FFI test on host | ✅ (host build) | ctest |
| On-device integration (real tiny models) | `app/integration_test/` | manual / device lab | `integration_test`, `flutter drive` |
| Benchmarks / evals | `tools/bench/` | nightly / manual | see `vv-benchmark-eval` |

## Acceptance tags (required — enforced by `tasks.py verify`)
- Every automatable acceptance criterion gets ≥ 1 test whose **name** contains `[<TASK-ID>/ACn]`
  (n = position of the bullet under the task's `## Acceptance Criteria`):
  ```dart
  test('[FND-05/AC1] killed mid-transcription job resumes without data loss', () async { … });
  testWidgets('[AUD-08/AC3] widget tests cover all recorder states', (t) async { … });
  ```
  C/C++: put the tag in the test name/comment (`TEST(Bridge, FND06_AC2)` + `// [FND-06/AC2]`);
  pytest: function name contains `FND_06_AC2` and a docstring with `[FND-06/AC2]`.
- The test must actually assert the criterion's number/threshold/failure path — hollow tests are
  rejected by the verifier (it mutates the code and expects the test to fail).
- Device-only criteria: rows in `docs/test-plans/device/<ID>.md` (template in `vv-task-verify`).
- Tagged tests are permanent: `tasks.py verify --all-done` runs in CI, so removing or renaming a
  tag breaks the build. Update the tag only together with an approved AC change.

## Rules
- Every task adds tests for the code it adds. Bug fix ⇒ failing test first.
- Coverage gate: ≥ 80% lines for `lib/**/domain/**` and `lib/core/**` (CI enforces via `lcov`).
- Prompt snapshots live in `app/test/golden_prompts/` (PRF-02).
- Deterministic: inject `Clock`, IDs, random seeds; LLM tests use `seed` + temperature 0.
- No real models in CI unit tests (too big). Fakes return scripted segments/tokens with delays
  to exercise progress/cancel paths.
- Native: build the bridge for the host (macOS/Linux) in CI and run a smoke test with the
  smallest model (`ggml-tiny.en` / a ≤ 200 MB GGUF) cached in CI — or skip with a clear message.
- Golden tests: fixed fonts (load in `flutter_test_config.dart`), both themes, text scale 1.0 and 2.0.
- Fixtures in `app/test/fixtures/`: 5–30 s WAV clips (16 kHz mono), transcripts JSON,
  expected Markdown. Keep each < 1 MB; no real personal recordings.

## Measuring UI jank
Use `SchedulerBinding.instance.addTimingsCallback` (`FrameTiming.totalSpan`) in an integration
test or `flutter drive --profile` + DevTools timeline; AC "no frame > 16 ms" means p99 build+raster
≤ 16 ms during the measured window on the named device.

## Fakes contract
Fakes implement the same interface as the real engine and must support: progress events,
cancellation mid-run, injected failures (`FakeSttEngine.failWith(Failure)`), and timing
(`Duration perChunk`). Pipeline tests must cover kill/resume by recreating the container
mid-job against the same DB file.

## On-device integration test (minimum flow)
1. Install `ggml-tiny.en` + smallest LLM via test-only model seeding: `tools/ci/fetch_test_models.sh`
   downloads them (sha256-pinned, cached; models are gitignored) and the test copies them into the
   app's models dir through a debug-only seeding hook.
2. Import fixture WAV → pipeline runs → assert transcript contains expected keywords.
3. Extraction with Meeting profile → schema-valid JSON.
4. Export to app-local vault target → file exists, front-matter parses.
Run: `cd app && fvm flutter test integration_test/e2e_test.dart -d <device>`.

## Stress / edge-case plan (QA-04)
Write `docs/test-plans/stress.md` as a table: scenario, steps, expected, device, result, date.
Must include: 3 h recording, 50 queued jobs, < 500 MB free, alarm/Bluetooth interruptions,
**calls (cellular + VoIP; incoming/outgoing; foreground/background/locked) → zero call audio,
no auto-resume, start refused during call (SEC-09)**,
force-kill at each pipeline step, reboot mid-job, permission revocation (mic, folder),
low-power mode, airplane mode, silence-only/music-only/non-English audio, OS upgrade.
"Zero data loss" = every recording either completes or is recoverable after relaunch.

## Device matrix (QA-05)
Maintain `docs/device-matrix.md`: device, SoC, RAM, OS, GPU backend status, owner, location.
Cloud device farms only for smoke tests with fixture audio — never real user audio.
