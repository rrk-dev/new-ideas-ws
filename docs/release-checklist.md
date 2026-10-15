# Release checklist (REL-01)

Copy this list into the release PR/issue for every `vX.Y.Z` and tick each item. A release is
started by pushing the tag; everything before that happens on a normal reviewed PR to `main`.

## Versioning scheme
- **Version name**: SemVer `MAJOR.MINOR.PATCH` in `app/pubspec.yaml` (`version: X.Y.Z+N`; the
  `+N` is only for local builds). MAJOR = incompatible data/format change, MINOR = features,
  PATCH = fixes only.
- **Tag**: `vX.Y.Z` on the merge commit in `main`; `tools/release/version.py check-tag` fails the
  release if it does not equal the pubspec version.
- **Build number**: `GITHUB_RUN_NUMBER + VV_BUILD_NUMBER_OFFSET` of the release workflow —
  monotonic and identical on both stores (Play `versionCode`, iOS `CFBundleVersion`). Re-running a
  failed release creates a new run and therefore a new build number (stores reject reused numbers).
- **Changelog**: generated from Conventional Commit subjects since the previous tag
  (`tools/release/changelog.py vX.Y.Z`); the short store version (`--store`) is sent as TestFlight
  "What to test" and Play release notes.

## Before tagging (release PR)
- [ ] Version bumped in `app/pubspec.yaml` (`X.Y.Z`), nothing else in the PR besides release prep.
- [ ] `python3 tools/release/changelog.py vX.Y.Z --since <previous tag>` reviewed; user-facing
      wording fixed via follow-up commits if needed (no transcript/user content in notes).
- [ ] All tasks shipped in this release are `done` (`tasks.py verify --all-done --run` green on `main`).
- [ ] **Store compliance (SEC-06)**: `PrivacyInfo.xcprivacy` up to date with every pod's manifest;
      App Store privacy label "Data Not Collected" and Play Data safety "No data collected/shared"
      still true; reviewer notes current (never records calls, user-tap start, model download sizes).
- [ ] **Licence screen**: About → "Open-source & model licenses" lists every new pub package,
      native library and model (SEC-05, `docs/licenses.md`).
- [ ] **Egress report**: latest egress test (SEC-02) run on this build candidate, hosts ⊆ allowlist,
      report committed to `docs/privacy-audit.md`.
- [ ] Recording policy check (`tools/ci/check_recording_policy.sh`) green — the release workflow
      re-runs it on the merged release manifest.
- [ ] **Size check**: `tools/ci/size_check.sh` (REL-03) within `tools/ci/size-budget.json`.
- [ ] CI on `main` green (all jobs).

## Release run (after `git tag vX.Y.Z && git push origin vX.Y.Z`)
- [ ] `release` workflow: `prepare`, `android`, `ios` green (approve the `release` environment).
- [ ] Build appears in TestFlight (internal) and the Play **internal** track with the expected
      version name and build number.
- [ ] **Smoke test on the oldest and newest device of each platform** (`docs/device-matrix.md`):
      install from TestFlight / Play internal, onboarding, record 1 min, transcribe, extract,
      export to a vault folder, kill + relaunch during processing, call interruption stops capture.
- [ ] **Symbols archived**: download `symbols-android-X.Y.Z-N` and `symbols-ios-X.Y.Z-N` artifacts
      (Dart `app.*.symbols`, `obfuscation_map.json`, unstripped `libvv_native.so`, app + `vv_native`
      dSYMs under `native/dSYMs/`,
      `SHA256SUMS`) and store them in the private release archive for the lifetime of the build
      (workflow artifacts expire after 90 days). Never upload them to third-party crash services or
      attach them to a public GitHub Release. Symbolication: `docs/crash-triage.md` (REL-02).
- [ ] Release notes (`release-notes` artifact) attached to the internal release record.

## Promotion (manual, outside the tag pipeline)
The tag workflow stops at TestFlight internal and the Play internal track.
Further promotion is the `beta` workflow (`.github/workflows/beta.yml`, REL-04).
Procedure, exit criteria and triage: `docs/beta.md`.

- [ ] After the internal build has finished processing, run **beta** → `external`
      (TestFlight group `VaultVoice External`) and **beta** → `closed` (Play
      closed testing, API track `alpha`).
- [ ] Triage feedback labelled `beta` (S1 data loss/crash blocks release, S2 wrong
      output, S3 UX). In-app path: Settings → Send beta feedback.
- [ ] Production only when `python3 tools/release/beta_gate.py <report.json>`
      exits 0: ≥ 50 testers with at least one on iOS and one on Android,
      crash-free sessions ≥ 99.5%, zero data-loss reports, extraction
      satisfaction ≥ 0.80, no open S1. The workflow's `production` action runs
      that gate and then only prepares a Play **draft** and selects the iOS
      build (`submit_for_review: false`). A human still submits for review.
- [ ] Post-release: watch App Store Connect / Play Console crash reports (OS-level opt-in baseline).
