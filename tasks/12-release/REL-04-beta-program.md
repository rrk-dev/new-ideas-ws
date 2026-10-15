# REL-04 — Beta Program (TestFlight / Play Testing)

**Workstream:** Release | **Phase:** 3–4 | **Size:** S | **Depends on:** REL-01 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-ci-release

## Goal
Validate on real users' devices and vaults before public launch.

## Scope
- [x] TestFlight external group and Play closed testing track.
- [x] In-app feedback (local: compose email / share with optional diagnostics from FND-07).
- [x] Beta exit criteria: crash-free sessions ≥ 99.5%, zero data-loss reports, extraction satisfaction survey ≥ target.
- [x] Triage process for beta feedback.

## Acceptance Criteria
- ≥ 50 beta users across platforms; exit criteria met before production release.

## Completion Notes
- **Agent:** Cursor · **Branch:** task/REL-04-beta-program · **Date:** 2026-10-14
- **Summary:** External beta is a manual promotion of the REL-01 internal build, not part of the tag workflow (that workflow must stay tag-only). `.github/workflows/beta.yml` runs `external` (TestFlight group `VaultVoice External`, fastlane 2.228 `distribute_only` + `distribute_external`) and `closed` (Play API track `alpha`). `production` runs `tools/release/beta_gate.py` first and then only prepares a Play draft and selects the iOS build without submitting it. In-app Settings → Send beta feedback shares a note through the OS sheet (Mail uses the subject) with an optional FND-07 diagnostics zip after the existing preview. Thresholds: `tools/release/beta_thresholds.json`. Triage and console setup: `docs/beta.md`. Wired from `docs/release-checklist.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [REL-04/AC1]; device: docs/test-plans/device/REL-04.md; artifact: docs/beta.md
- **Decisions:** no ADR. Satisfaction target 0.80 and “both platforms, total ≥ 50” are marked PRODUCT-DECISION in `docs/beta.md`. No beta inbox is compiled into the app (share sheet only). Production does not auto-submit for review.
- **Follow-ups:** QA-05 beta-review block in `docs/parity.md` before the external track opens (already listed below).
- **Gates:** `fvm dart format --set-exit-if-changed .` 0 changed; `fvm flutter analyze` no issues; `fvm dart analyze --fatal-infos` no issues; `fvm flutter test` 1369 passed / 52 skipped (Linux goldens on macOS); `python3 -m pytest tools/release/tests/test_beta_program.py` 4 passed; `python3 -m pytest tools/ci/tests` 91 passed; `check_recording_policy.sh` OK; `check_egress.sh` OK; `check_codegen.sh` OK (build_runner no diff); `tasks.py validate` 0 problems. Not executed: fastlane / Xcode / Android SDK (same as REL-01).

## Follow-ups
- QA-05: sign the beta-review block in `docs/parity.md` before the external TestFlight / Play track opens. Confirm Ogg/Opus (unsupported on iOS) and the call guard on one in-lab phone per platform.
- Settings goldens: `tools/ci/update_goldens.sh test/golden/settings_screen_golden_test.dart` aborted in podman (`The Dart compiler exited unexpectedly`). The new About tile sits below the 390×844 fold; re-run on a Linux CI runner if APP-03 goldens fail.
