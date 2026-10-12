# SEC-06 — App Store / Play Privacy & Policy Compliance (Engineering)

**Workstream:** Security & Privacy | **Phase:** 4 | **Size:** S | **Depends on:** SEC-02, MDL-02 | **Source:** §5 Phase 4 (privacy policies) + Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-ci-release

## Goal
Pass store review on first submission.

## Scope
- [ ] iOS `PrivacyInfo.xcprivacy` privacy manifest (required-reason APIs: file timestamps, disk space, UserDefaults) for app and all SDKs.
- [ ] App Privacy "nutrition label" and Play Data Safety form: "No data collected" — verify true.
- [ ] Downloaded models: confirm compliance with App Store Guideline 2.5.2 (models are data, not executable code) and Play policy; prepare reviewer notes.
- [ ] Large on-demand downloads: guideline 4.2 / initial download disclosure.
- [ ] Usage-description strings for microphone, background modes justification.
- [ ] Store listing, screenshots and in-app copy never claim or imply phone/VoIP call recording; Play declarations list no call-log/phone-state permissions; SEC-09 policy check passes on the release build.
- [ ] In-app link to privacy policy (content provided by business side).

## Acceptance Criteria
- Pre-submission checklist completed; TestFlight external review and Play pre-launch report pass.
