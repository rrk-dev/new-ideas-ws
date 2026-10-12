# EXP-05 — Vault Writer & Folder Routing Rules Engine

**Workstream:** Export | **Phase:** 3 | **Size:** M | **Depends on:** EXP-02, EXP-03, EXP-04, LIC-01 | **Source:** §3.1.4, §4.2 (Local File Router), §5 Phase 3, §7 (Multiple folder routing rules — Pro)
**Status:** todo
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-licensing-iap, vv-local-database, vv-pipeline-orchestrator, vv-testing

## Goal
Route each rendered note to the right destination(s) based on rules.

## Scope
- [ ] `VaultTarget` abstraction over SAF (Android) and bookmarks (iOS) + app-local folder.
- [ ] Rules: match on profile, tags, keywords, speaker names, auto-classification result → target + sub-path + filename pattern. Ordered, first-match or multi-match.
- [ ] Free tier: one target; Pro: multiple targets and rules (LIC-01).
- [ ] Optional sidecar outputs: transcript `.md`, audio file copy (m4a) into vault `attachments/`.
- [ ] Atomic write (temp file + rename where supported).

## Acceptance Criteria
- Rules engine unit tests cover ordering, multi-match, and fallback target.
- End-to-end: recording → note lands in the rule-selected vault folder on both platforms.
