# REL-04 — Beta Program (TestFlight / Play Testing)

**Workstream:** Release | **Phase:** 3–4 | **Size:** S | **Depends on:** REL-01 | **Source:** Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-ci-release

## Goal
Validate on real users' devices and vaults before public launch.

## Scope
- [ ] TestFlight external group and Play closed testing track.
- [ ] In-app feedback (local: compose email / share with optional diagnostics from FND-07).
- [ ] Beta exit criteria: crash-free sessions ≥ 99.5%, zero data-loss reports, extraction satisfaction survey ≥ target.
- [ ] Triage process for beta feedback.

## Acceptance Criteria
- ≥ 50 beta users across platforms; exit criteria met before production release.

## Follow-ups
- QA-05: sign the beta-review block in `docs/parity.md` before the external TestFlight / Play track opens. Confirm Ogg/Opus (unsupported on iOS) and the call guard on one in-lab phone per platform.
