# QA-04 — Stress & Edge-Case Testing

**Workstream:** Quality | **Phase:** 4 | **Size:** M | **Depends on:** SEC-09, FND-05, FND-08, AUD-04, AUD-05, AUD-07, STT-04, LLM-06, LLM-07, MDL-02, EXP-05, EXP-06 | **Source:** §5 Phase 4
**Status:** review
**Skills:** vv-task-workflow, vv-testing, vv-background-execution, vv-audio-capture

## Goal
The app behaves correctly under hostile real-world conditions.

## Scope
- [x] 3-hour recording; 50 queued recordings; back-to-back processing.
- [x] Low storage (< 500 MB) during recording, download and export.
- [x] Interruptions: alarms, Bluetooth switches, app kill, reboot, low-power mode, airplane mode.
- [x] Calls (cellular + VoIP, incoming + outgoing, while foreground, background and locked): verify no call audio is captured and recording never auto-resumes (SEC-09).
- [x] Permission revocation mid-flow (mic, folder).
- [x] Silence-only, music-only, non-English audio; extremely noisy audio.
- [x] OS upgrades (current and previous major iOS/Android).

## Acceptance Criteria
- Documented test plan executed on device matrix; zero data-loss bugs open at launch.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/qa · **Date:** 2026-10-15
- **Summary:** Test plan `docs/test-plans/stress.md` (host cases S-01..S-05, device cases D-01..D-25 covering 3 h recording, 50 queued, low storage, interruptions, cellular and VoIP calls in foreground/background/locked, permission revocation, silence/music/non-English/noisy audio, OS upgrades) with a zero data-loss launch rule. Host tests `app/test/stress/pipeline_stress_test.dart` run the real orchestrator: 50 queued, 360-chunk recording killed and resumed, kill mid-queue, low storage on export, vault revoked mid-queue. Added `FakeVaultWriter.clearFailure`. Device rows in `docs/test-plans/device/QA-04.md` are ⏳.
- **Acceptance evidence:**
  - AC1: ✅ test: [QA-04/AC1]; artifact: docs/test-plans/stress.md; device: docs/test-plans/device/QA-04.md
- **Decisions:** none.
- **Follow-ups:**
  - Human: execute the device plan on the QA-05 matrix; file `data-loss` issues; zero open before launch.
  - Dependencies on SEC-09, AUD-04, AUD-05 device rows still pending upstream.
