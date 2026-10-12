# SEC-08 — Threat Model & Pre-Launch Security Review

**Workstream:** Security & Privacy | **Phase:** 2 (model) / 4 (review) | **Size:** M | **Depends on:** SEC-01, SEC-02, MDL-01 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-ffi-bridge, vv-ci-release, vv-testing

## Goal
Systematically identify and mitigate threats before launch.

## Scope
- [ ] STRIDE threat model: malicious model file (GGUF parser bugs), tampered manifest, malicious imported profile/template, prompt injection via spoken content, **misuse for covert recording or call recording (verify SEC-09 controls cannot be bypassed via settings, MDM, intents, deep links or widgets)**, lost/stolen device, malicious audio file import (decoder bugs), license forgery.
- [ ] Fuzz native entry points (GGUF loading, WAV parsing) with libFuzzer on desktop builds.
- [ ] Dependency vulnerability scanning in CI (OSV-scanner for pub + native submodules).
- [ ] Pre-launch internal pen test / MobSF scan.

## Acceptance Criteria
- Threat model doc with mitigations mapped to tasks; no open high/critical findings at launch.
