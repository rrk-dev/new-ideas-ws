# FND-03 — Continuous Integration Pipeline

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** Gap (no CI defined)
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release, vv-testing, vv-privacy-security, vv-native-build, vv-ffi-bridge

## Notes
- This is a **bootstrap** task: nothing outside FND-01/02/03, QA-01, QA-05 can be verified `done` until it is.

## Goal
Every change is formatted, analyzed, tested and built for both platforms, including native C/C++ libraries.

## Scope
- [x] CI jobs: format check, analyze, unit + widget tests with coverage report.
- [x] Android build job producing a debug APK (`fvm flutter build apk --flavor dev -t lib/main_dev.dart`). FND-06 later adds the native libs (`libvv_native.so`) to this job.
- [x] iOS build job on macOS runner producing an unsigned build (FND-06 adds `vv_native.xcframework`).
- [x] Cache Flutter pub, Gradle, CocoaPods/SPM and native build artifacts (ccache).
- [x] `tools/ci/check_egress.sh` (minimal version; SEC-02 extends it) as a PR job, plus a job slot for `tools/ci/check_recording_policy.sh` (script delivered by SEC-09).
- [x] `tasks.py validate` and `tasks.py verify --all-done --run` as blocking PR jobs (independent-verification gate).
- [x] Job slots/scripts for native host smoke tests (`ci/native_host.sh`) — filled in by FND-06.
- [~] deferred → admin action: Branch protection: CI must pass before merge. (command + required checks documented in `docs/ci.md`; needs repo admin, not applied)

## Acceptance Criteria
- A PR triggers all jobs; total pipeline time < 25 min with warm caches.
- Failing lint/test blocks merge.
- A PR that sets a task to `done` without a passing `tasks.py verify` (e.g. missing tagged test or verification report) fails CI (demonstrated on a test branch).
- Build artifacts downloadable from CI for QA.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-03-ci-pipeline (stacked on FND-02 → FND-01) · **Date:** 2026-10-12
- **Summary:** GitHub Actions workflow `.github/workflows/ci.yml` (jobs `static`, `test`, `task-gate`, `android`,
  `ios`, `native-host`) wrapping scripts in `tools/ci/` (`setup`, `format`, `analyze` (flutter + dart analyze),
  `test` + `check_coverage.py` (≥ 80% over core/domain), `check_codegen`, `check_egress` (minimal), `build_android`,
  `build_ios`, `run_slot` for `check_recording_policy.sh` (SEC-09) and `native_host.sh` (FND-06)). `tasks.py validate`
  and `verify --all-done --run` are blocking jobs. Caches for fvm/pub/Gradle/Pods/ccache; artifacts uploaded
  (APK, unsigned iOS app zip, lcov). Added `app/test/unit/providers_test.dart` (FND-02 code) to lift core
  coverage 77.8% → 92.1% so the gate passes honestly. Docs: `docs/ci.md`.
  Not done / unverified: the workflow has never run on GitHub; Android/iOS builds were not run locally (no SDK/Xcode);
  branch protection needs a repo admin; slots only warn until SEC-09 / FND-06 deliver their scripts.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/FND-03.md
  - AC2: ⏳ test: [FND-03/AC2]; device: docs/test-plans/device/FND-03.md
  - AC3: ⏳ test: [FND-03/AC3]; device: docs/test-plans/device/FND-03.md
  - AC4: ⏳ device: docs/test-plans/device/FND-03.md
- **Decisions:** none (GitHub Actions chosen from the `origin` remote; scripts stay runner-agnostic)
- **Follow-ups:** apply branch protection (repo admin); FND-06 to fill `native_host.sh` and add native libs to the Android/iOS jobs; SEC-09 to deliver `check_recording_policy.sh`; SEC-02 to extend `check_egress.sh`


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ Public PR run 50 (8m 59s) and main run 51 (9m 46s) show six successful jobs, under 25 minutes. Cache wiring inspected; cache-hit logs were not independently confirmed.
  - AC2: ❌ Local gate tests reject forbidden egress and 70% coverage and propagate slot exit 3; workflow invokes format/analyze/test. No live failing lint/test PR with merge blocked is recorded; docs/ci.md explicitly leaves branch protection to an admin.
  - AC3: ❌ Sandbox test flips FND-02 to done without a report and asserts verification failure, then invalidates a tag. It is meaningful local proof; the explicitly required throwaway-branch CI demonstration has no run URL/result.
  - AC4: ✅ Public summaries list android-dev-debug-apk, ios-dev-unsigned-app and coverage-lcov artifacts with sizes/digests. Downloads/install were not performed anonymously; checklist rows remain blank.
- **Adversarial checks:** Changed check_coverage.py default threshold from 80 to 60; [FND-03/AC2] low-coverage rejection test failed, then passed after git checkout restored the file. Read fail-closed evidence checks and workflow job dependencies. Public HTML fetched with curl only; no gh/API/authenticated access.
- **Skill/rule compliance:** Runner wrappers call plain scripts; coverage, egress, task gate, native host build, merged-manifest policy and artifact upload are wired. These local/source checks do not establish server-side merge protection. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** 
  1. AC2 has no checkable evidence that failing lint and failing tests block merge through required checks. Supply a protected-branch failing-PR demonstration (no admin changes performed by this verifier).
  2. AC3 explicitly requires a test-branch CI demonstration. The sandbox unit test and green runs 50/51 do not supply it; record the failed task-gate run URL and observed refusal.
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-03 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/FND-03-verify.log`.

## Rework
- **Agent:** Claude Code · **Branch:** task/FND-03-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged). Notes only, no code change.
- **Why implementers cannot close these:** `ci.yml` runs on `pull_request` and on `push` to `main` only, so a pushed `task/*` branch alone starts no run; implementers must not open PRs or call the GitHub API in this batch, and applying branch protection needs repo-admin rights. Both issues therefore need the **repo owner (rrk-dev)**. AC2/AC3 stay ⏳ in `docs/test-plans/device/FND-03.md`; the local proofs (`[FND-03/AC2]`, `[FND-03/AC3]` in `tools/ci/tests/`) are unchanged.
- **Issue 1 (AC2 — failing lint/test must block merge), owner steps:**
  1. Apply branch protection on `main` with the six required checks `static`, `test`, `task-gate`, `android`, `ios`, `native-host` (command in `docs/ci.md` → "Branch protection", or Settings → Branches → Add rule → "Require status checks to pass" + "Require a pull request before merging" + "Do not allow bypassing").
  2. `git switch -c ci-demo/lint origin/main`; append an unformatted line (e.g. `int  x=1;`) to `app/lib/core/app_info.dart`; commit, push, open a **draft** PR to `main`. Expected: `static` fails at `format.sh` naming the file; merge button blocked ("Required statuses must pass").
  3. `git switch -c ci-demo/test origin/main`; add `app/test/ci_demo_test.dart` with `test('ci demo', () => expect(1, 2));`; push, draft PR. Expected: `test` fails; merge blocked.
  4. Paste both run URLs + a screenshot of the blocked merge box into the AC2 row (Result/Date/Tester), close both PRs without merging, delete the branches.
- **Issue 2 (AC3 — task-gate demonstration on a test branch), owner steps:**
  1. `git switch -c ci-demo/fake-done origin/main`; edit a task with no Completion Notes or Verification Report (e.g. `tasks/06-profiles/PRF-04-warranty-receipt-profile.md`) by hand to `**Status:** done` (`tasks.py set` refuses, which is expected); commit, push, open a draft PR.
  2. Expected: `task-gate` fails at `tasks.py verify --all-done --run` with lines such as `PRF-04: FAIL missing '## Completion Notes'` and `PRF-04: FAIL missing '## Verification Report' …` (checked locally with `tasks.py verify PRF-04` on 2026-10-14); merge blocked once protection is on.
  3. Paste the run URL and the observed refusal line into the AC3 row; close the PR unmerged, delete the branch.
- **AC1/AC4:** already ✅ per the report (runs 50/51 and their artifacts); the AC4 row's APK install on an arm64 emulator remains for whoever has an Android emulator.
