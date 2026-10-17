# APP-09 — Live waveform while recording

**Workstream:** App UX | **Phase:** 4 | **Size:** S | **Depends on:** APP-08 | **Source:** User request 2026-10-16
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-audio-capture, vv-testing

## Goal
While recording, the Record screen shows a smooth, calm live waveform driven by the microphone level, so the user can see Lumen is listening.

## Scope
- [x] `LiveWaveform` widget: scrolling bars (newest on the right) fed by the existing `recordingLevelsProvider` readings (20 Hz); a fixed-size ring buffer; painted with a `CustomPainter` inside a `RepaintBoundary`; teal bars, error colour on clipping.
- [x] Replaces the thin level bar on the Record screen while recording; idle and paused show flat low bars.
- [x] Reduced motion (MediaQuery.disableAnimations): static level bars instead of scrolling; works in light and dark; has a semantic label and does not announce every update.
- [x] No new audio taps, native code, or network; no content is stored or logged.

## Acceptance Criteria
- The waveform shows the last N level readings, and the newest reading appears at the right edge (unit test on the ring buffer and painter input).
- Clipping readings are drawn in the error colour (widget test).
- With reduced motion enabled the widget does not animate (widget test).
- The Record screen renders without overflow at text scale 2.0 in light and dark, and the Record golden is updated.
- Painting a full buffer does not rebuild the rest of the screen (`RepaintBoundary` present; widget test).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/APP-08-modern-ui · **Date:** 2026-10-17
- **Summary:** `lib/features/recording/presentation/live_waveform.dart`: `WaveformBuffer` (fixed ring, `ChangeNotifier`), `WaveformPainter` (rounded centred bars, newest right, fading older bars, error colour on clipping, static bars under reduced motion) and `LiveWaveform` (listens to `recordingLevelsProvider`, `RepaintBoundary`, one semantic label, clipping hint live region). Replaces `LevelMeterBar` on the Record screen (idle/paused: flat low bars); waveform sizes are tokens in `app_tokens.dart`. Record goldens regenerated on Linux. `LevelMeterBar` remains for the dev debug screen.
- **Acceptance evidence:**
  - AC1: ✅ test: [APP-09/AC1]
  - AC2: ✅ test: [APP-09/AC2]
  - AC3: ✅ test: [APP-09/AC3]
  - AC4: ✅ test: [APP-09/AC4]
  - AC5: ✅ test: [APP-09/AC5]
- **Decisions:** none
- **Follow-ups:** none
