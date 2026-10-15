# SEC-06 — App Store / Play Privacy & Policy Compliance (Engineering)

**Workstream:** Security & Privacy | **Phase:** 4 | **Size:** S | **Depends on:** SEC-02, MDL-02 | **Source:** §5 Phase 4 (privacy policies) + Gap
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-ci-release

## Goal
Pass store review on first submission.

## Scope
- [x] iOS `PrivacyInfo.xcprivacy` privacy manifest (required-reason APIs: file timestamps, disk space, UserDefaults) for app and all SDKs.
- [x] App Privacy "nutrition label" and Play Data Safety form: "No data collected" — verify true.
- [x] Downloaded models: confirm compliance with App Store Guideline 2.5.2 (models are data, not executable code) and Play policy; prepare reviewer notes.
- [x] Large on-demand downloads: guideline 4.2 / initial download disclosure.
- [x] Usage-description strings for microphone, background modes justification.
- [x] Store listing, screenshots and in-app copy never claim or imply phone/VoIP call recording; Play declarations list no call-log/phone-state permissions; SEC-09 policy check passes on the release build.
- [x] In-app link to privacy policy (content provided by business side).

## Acceptance Criteria
- Pre-submission checklist completed; TestFlight external review and Play pre-launch report pass.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/expsec · **Date:** 2026-10-15
- **Summary:** Added `PrivacyInfo.xcprivacy` for the Runner target (wired into the Xcode Resources phase) and the `vv_native` pod (podspec resource bundle): no tracking, no collected data, required-reason codes for file timestamp, disk space and user defaults. `tools/ci/check_store_privacy.sh` (CI `static` job) checks manifests, undeclared required-reason API use in first-party Swift, usage strings, background modes, Android permissions/meta-data, call-recording claims in listing and in-app copy, and the policy link. Settings → About → Privacy policy opens a bundled, offline policy screen (draft text, business replaces it). `docs/store/` has the listing copy, label/Data Safety evidence, reviewer notes (2.5.2, 4.2, background modes) and the pre-submission checklist.
- **Acceptance evidence:**
  - AC1: ⏳ test: [SEC-06/AC1]; device: docs/test-plans/device/SEC-06.md; ci: tools/ci/check_store_privacy.sh in the CI static job
- **Decisions:** none
- **Follow-ups:** see below.

## Follow-ups
- Humans: generate the Xcode Privacy Report on an archive, fill App Store Connect / Play Console forms, supply the final privacy policy and URL, run TestFlight external review and the Play pre-launch report (`docs/store/pre-submission-checklist.md`).
- Fill in the smallest model size in `docs/store/reviewer-notes.md` once the catalog is final.
- Pod manifests of third-party Flutter plugins were not inspected (no `pod install` here); the privacy report in the checklist covers them.
- macOS runner (FND-09) has no manifest yet; the CI check validates any `app/macos/**/PrivacyInfo.xcprivacy` once it exists.
