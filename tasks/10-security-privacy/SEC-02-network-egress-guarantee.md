# SEC-02 — Network Egress Guarantee & Verification

**Workstream:** Security & Privacy | **Phase:** 2–4 | **Size:** M | **Depends on:** MDL-02, LIC-02 | **Source:** §1 ("without ever sending byte zero of data to a cloud server") + Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-privacy-security, vv-ci-release, vv-model-delivery, vv-testing

## Goal
Make the privacy promise verifiable: user content never leaves the device, and all network use is enumerated.

## Scope
- [ ] Single `NetworkGateway` in Dart; lint/CI check banning direct `http`/`dio`/`HttpClient` use elsewhere.
- [ ] Allowlist: model manifest + model hosts. Nothing else. (Store billing runs inside StoreKit/Play Billing OS frameworks, outside our client — document it in the privacy audit.)
- [ ] Audit all third-party packages for hidden network calls/telemetry; dependency review checklist for new packages.
- [ ] iOS App Transport Security locked to allowlisted domains; Android Network Security Config.
- [ ] "Offline mode" toggle that disables all network (models must be installed).
- [ ] Automated test: run full pipeline with a proxy recording all traffic → assert zero requests outside allowlist.
- [ ] In-app "Network activity" log showing every request made.

## Acceptance Criteria
- CI egress test passes; package audit documented in `docs/privacy-audit.md`.
