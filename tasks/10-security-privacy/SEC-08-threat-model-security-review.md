# SEC-08 — Threat Model & Pre-Launch Security Review

**Workstream:** Security & Privacy | **Phase:** 2 (model) / 4 (review) | **Size:** M | **Depends on:** SEC-01, SEC-02, MDL-01 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-ffi-bridge, vv-ci-release, vv-testing

## Goal
Systematically identify and mitigate threats before launch.

## Scope
- [x] STRIDE threat model: malicious model file (GGUF parser bugs), tampered manifest, malicious imported profile/template, prompt injection via spoken content, **misuse for covert recording or call recording (verify SEC-09 controls cannot be bypassed via settings, MDM, intents, deep links or widgets)**, lost/stolen device, malicious audio file import (decoder bugs), license forgery.
- [x] Fuzz native entry points (GGUF loading, WAV parsing) with libFuzzer on desktop builds.
- [x] Dependency vulnerability scanning in CI (OSV-scanner for pub + native submodules).
- [x] Pre-launch internal pen test / MobSF scan.

## Acceptance Criteria
- Threat model doc with mitigations mapped to tasks; no open high/critical findings at launch.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/qa · **Date:** 2026-10-15
- **Summary:** `docs/threat-model.md`: STRIDE table (16 threats incl. covert/call recording, SEC-09 bypass review across settings, MDM, intents, deep links, widgets), findings register (no open High/Critical), pen test and MobSF runbook, pre-launch gate. Fuzzing: `native/fuzz/` (WAV and GGUF libFuzzer targets, standalone ASan/UBSan mutation driver, seeds, `build_fuzz.sh`); the WAV run was executed here, GGUF needs a libFuzzer host. Dependency scan: `tools/ci/osv_scan.sh`, `osv-scanner.toml`, `.github/workflows/osv.yml` (OSV-Scanner v2.7.0, checksum-verified). Tests: `tools/ci/tests/test_sec08_threat_model.py`. The MobSF/pen test and 1 h fuzz runs are scope items delivered as runbooks and device rows; execution is a human launch gate.
- **Acceptance evidence:**
  - AC1: ✅ test: [SEC-08/AC1]; artifact: docs/threat-model.md; device: docs/test-plans/device/SEC-08.md
- **Decisions:** none (no technology choice; OSV-Scanner is the tool named by the task).
- **Follow-ups:**
  - Human: run MobSF, pen test and 1 h libFuzzer runs on the release candidate; first OSV CI run triage.
  - F-03 (Low): restrict the `.vvprofile` intent filter to `content://` where possible.
  - Re-review the SEC-09 bypass table when LIC-04 (managed configuration) merges.
