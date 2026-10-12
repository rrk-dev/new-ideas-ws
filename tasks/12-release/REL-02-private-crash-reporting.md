# REL-02 — Privacy-Preserving Crash Reporting

**Workstream:** Release | **Phase:** 4 | **Size:** S | **Depends on:** FND-07 | **Source:** Gap (no Crashlytics/Sentry cloud by default given privacy promise)
**Status:** todo
**Skills:** vv-task-workflow, vv-ci-release, vv-privacy-security, vv-ffi-bridge, vv-decision-records, vv-testing

## Goal
Get actionable crash data without violating "no data leaves the device".

## Scope
- [ ] Capture Dart + native (signal handler) crashes to local files.
- [ ] On next launch, offer "Send crash report" — user reviews content, sends via email/share sheet. No upload endpoint (egress policy) unless a future ADR adds one to the allowlist.
- [ ] Rely on App Store Connect / Play Console OS-level crash reports (users' OS-level opt-in) as baseline.
- [ ] Symbolication tooling using privately stored symbols (REL-01).

## Acceptance Criteria
- A forced native crash produces a symbolicated report from a user-shared file.
