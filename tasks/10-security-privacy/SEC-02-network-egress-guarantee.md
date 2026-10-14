# SEC-02 — Network Egress Guarantee & Verification

**Workstream:** Security & Privacy | **Phase:** 2–4 | **Size:** M | **Depends on:** MDL-02, LIC-02 | **Source:** §1 ("without ever sending byte zero of data to a cloud server") + Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-privacy-security, vv-ci-release, vv-model-delivery, vv-testing

## Goal
Make the privacy promise verifiable: user content never leaves the device, and all network use is enumerated.

## Scope
- [x] Single `NetworkGateway` in Dart; lint/CI check banning direct `http`/`dio`/`HttpClient` use elsewhere.
- [x] Allowlist: model manifest + model hosts. Nothing else. (Store billing runs inside StoreKit/Play Billing OS frameworks, outside our client — document it in the privacy audit.)
- [x] Audit all third-party packages for hidden network calls/telemetry; dependency review checklist for new packages.
- [x] iOS App Transport Security locked to allowlisted domains; Android Network Security Config.
- [x] "Offline mode" toggle that disables all network (models must be installed).
- [x] Automated test: run full pipeline with a proxy recording all traffic → assert zero requests outside allowlist.
- [x] In-app "Network activity" log showing every request made.

## Acceptance Criteria
- CI egress test passes; package audit documented in `docs/privacy-audit.md`.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/SEC-02-network-egress-guarantee (stacked on
  task/SEC-03-app-lock → SEC-04 → SEC-01, to avoid conflicts in Settings and the accessibility
  test) · **Date:** 2026-10-14
- **Dependencies:** MDL-02 is in review; LIC-02 is `todo` — it only matters for documenting store
  billing (OS frameworks, outside our client), which `docs/privacy-audit.md` already states.
- **Summary:**
  - `tools/ci/check_egress.sh` hardened: Dart/Kotlin/Java/Swift/ObjC network, socket, URL and
    web-view APIs outside the gateway dirs (comment lines ignored), forbidden telemetry/network
    deps in pubspec **and** Gradle, Android cleartext / missing network security config / user CAs
    outside `debug-overrides`, iOS ATS exceptions. Tests: `tools/ci/tests/test_egress_guard.py`.
  - Android `res/xml/network_security_config.xml` + `usesCleartextTraffic="false"`; iOS
    `NSAppTransportSecurity { NSAllowsArbitraryLoads = false }`.
  - Package audit: `tools/ci/audit_packages.py` + `tools/ci/check_packages.sh` (runtime closure
    from `pub deps --json`, sources from `package_config.json`), reviewed hits in
    `tools/ci/package_audit.json`, table in `docs/privacy-audit.md`.
  - Gateway activity log (`app/lib/core/network/network_activity.dart`): every completed /
    denied / failed / handed-to-system request (time, host, path, status, bytes — no query,
    headers or body), persisted in `vv/network/activity.jsonl`; Settings → Privacy → Network
    activity screen; cleared by "Delete all data".
  - Settings → Privacy → Offline mode (`network_disabled`, the key the gateway and the
    downloader already honour).
  - Host egress capture test with a recording proxy over a whole session (catalog, model
    download + redirect, full pipeline) and in offline mode.
  - **CI step to add (ci.yml not edited):** in the `static` job after `setup.sh`:
    `- run: bash tools/ci/check_packages.sh`.
  - Note: the claim commit on this branch carries the message "chore(SEC-03): hand off for
    review" (a stray background commit; it contains the claim + the first activity-log file).
- **Acceptance evidence:**
  - AC1: ⏳ test: [SEC-02/AC1]; artifact: docs/privacy-audit.md; device: docs/test-plans/device/SEC-02.md
- **Decisions:** none new (allowlist per ADR-MDL-01/02). PRODUCT-DECISION: the network activity
  log keeps the last 500 requests.
- **Follow-ups:** add `check_packages.sh` to CI (above); SEC-06 uses the capture report for the
  store "Data not collected" answers.
