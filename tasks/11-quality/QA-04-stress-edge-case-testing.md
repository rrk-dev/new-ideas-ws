# QA-04 — Stress & Edge-Case Testing

**Workstream:** Quality | **Phase:** 4 | **Size:** M | **Depends on:** SEC-09, FND-05, FND-08, AUD-04, AUD-05, AUD-07, STT-04, LLM-06, LLM-07, MDL-02, EXP-05, EXP-06 | **Source:** §5 Phase 4
**Status:** todo
**Skills:** vv-task-workflow, vv-testing, vv-background-execution, vv-audio-capture

## Goal
The app behaves correctly under hostile real-world conditions.

## Scope
- [ ] 3-hour recording; 50 queued recordings; back-to-back processing.
- [ ] Low storage (< 500 MB) during recording, download and export.
- [ ] Interruptions: alarms, Bluetooth switches, app kill, reboot, low-power mode, airplane mode.
- [ ] Calls (cellular + VoIP, incoming + outgoing, while foreground, background and locked): verify no call audio is captured and recording never auto-resumes (SEC-09).
- [ ] Permission revocation mid-flow (mic, folder).
- [ ] Silence-only, music-only, non-English audio; extremely noisy audio.
- [ ] OS upgrades (current and previous major iOS/Android).

## Acceptance Criteria
- Documented test plan executed on device matrix; zero data-loss bugs open at launch.
