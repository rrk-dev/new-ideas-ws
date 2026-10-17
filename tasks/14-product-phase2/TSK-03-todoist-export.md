# TSK-03 — Export action items to Todoist (opt-in, only if approved in TSK-01)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** TSK-01, TSK-02, SEC-02, SEC-06, LIC-05 | **Source:** User decision 2026-10-16 (product Phase 2: Todoist export; needs an egress policy check)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-ci-release, vv-licensing-iap, vv-testing

## Goal
If, and only if, ADR-TSK-01 is Accepted with a "ship" or "opt-in" decision for Todoist, a user can explicitly connect their Todoist account and push selected action items.

## Scope
- [ ] **Do not start until a human has marked ADR-TSK-01 Accepted and the Todoist decision is not "no-go".** If it is "no-go", set this task `blocked` with `**Blocked by:** ADR-TSK-01 no-go` (there is no won't-do status) and tell the user.
- [ ] Gateway write support: `NetworkGateway` currently exposes `get`, `authorize` and `getStream` only. Add scoped POST support (auth header, body-safe logging, offline/MDM checks, redirect handling) and tests; allowlisting a host alone does not make export possible.
- [ ] Account the traffic by phase as ADR-TSK-01 decides: authorisation (browser/app vs client), project discovery, and content export. Confirmation of the exact text is required before any request that carries task content; the egress report states which hosts each phase uses.
- [ ] Add the Todoist host(s) named in the ADR to the `NetworkGateway` allowlist through the documented process, with a distinct gateway purpose so the Network activity log labels these requests; update ATS / Network Security Config, `tools/ci/check_egress.sh` and the egress test, and keep model hosts separate from integration hosts.
- [ ] Connection flow exactly as decided (OAuth or token); secret stored only in the platform secure store and excluded from backups; disconnect and **Delete all data** (`SecureDataWiper`) both delete it and the connection state (fake secure-store test); never logged; Integrations setting off by default and forced off by offline mode and MDM `network_disabled`.
- [ ] Exporter reusing the TSK-01 shared item model and TSK-02's selection UI and idempotency table: per-push confirmation showing the exact task texts that will be sent, project picker, due date only from `due_iso`, rate-limit and error handling per the API docs verified in TSK-01.
- [ ] Request/response bodies and Todoist task text are never written to logs or crash reports; error messages shown to the user contain no task text.
- [ ] Update `docs/privacy-audit.md`, the store privacy answers (SEC-06) and the in-app privacy text to describe this opt-in data flow accurately.
- [ ] Tests: gateway tests with a fake transport (allowed host only, offline mode blocks, MDM blocks); contract tests against recorded fixtures; widget tests; egress test updated.

## Acceptance Criteria
- The egress test shows only the host(s) named in the accepted ADR, only when the user has connected Todoist and confirmed a push; with Integrations off, offline mode on or `network_disabled` set, zero requests to it (`[TSK-03/AC1]`).
- Every push requires a confirmation that lists the text to be sent; cancelling sends nothing (widget test `[TSK-03/AC2]`).
- The access secret exists only in secure storage, is removed on disconnect and never appears in logs or the Network activity log (test `[TSK-03/AC3]`).
- A second push does not duplicate tasks; API errors, revoked authorisation and rate limits give recoverable user messages (tests with fixtures `[TSK-03/AC4]`).
- `docs/privacy-audit.md`, SEC-06 store answers and in-app privacy text mention the integration; a docs test or checklist row fails if the new host is missing from the audit.
- A real Todoist test account round trip on a physical device (device row `docs/test-plans/device/TSK-03.md`, ⏳ until run).
