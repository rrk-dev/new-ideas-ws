# FND-07 — Local-Only Logging & Diagnostics

**Workstream:** Foundation | **Phase:** 1 | **Size:** S | **Depends on:** FND-02 | **Source:** Gap (privacy promise rules out cloud telemetry)
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-benchmark-eval, vv-testing

## Goal
Developers and users can diagnose problems without any data leaving the device unless the user explicitly shares it.

## Scope
- [ ] Structured logger with levels, rotating log files in app-private storage (size cap).
- [ ] Redaction: never log transcript text, audio paths containing names, or LLM outputs at INFO+.
- [ ] Performance metrics captured locally (RTF, tokens/sec, peak RAM, battery delta) per job — feeds QA-03.
- [ ] "Export diagnostics" action: user-initiated zip via OS share sheet, with preview of contents.
- [ ] No third-party analytics/crash SDKs (see REL-02 for crash handling).

## Acceptance Criteria
- Log files rotate at configured size; redaction unit tests pass.
- Diagnostics export contains logs + device info + metrics and no transcript content.
