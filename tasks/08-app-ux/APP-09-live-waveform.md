# APP-09 — Live waveform while recording

**Workstream:** App UX | **Phase:** 4 | **Size:** S | **Depends on:** APP-08 | **Source:** User request 2026-10-16
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-audio-capture, vv-testing

## Goal
While recording, the Record screen shows a smooth, calm live waveform driven by the microphone level, so the user can see Lumen is listening.

## Scope
- [ ] `LiveWaveform` widget: scrolling bars (newest on the right) fed by the existing `recordingLevelsProvider` readings (20 Hz); a fixed-size ring buffer; painted with a `CustomPainter` inside a `RepaintBoundary`; teal bars, error colour on clipping.
- [ ] Replaces the thin level bar on the Record screen while recording; idle and paused show flat low bars.
- [ ] Reduced motion (MediaQuery.disableAnimations): static level bars instead of scrolling; works in light and dark; has a semantic label and does not announce every update.
- [ ] No new audio taps, native code, or network; no content is stored or logged.

## Acceptance Criteria
- The waveform shows the last N level readings, and the newest reading appears at the right edge (unit test on the ring buffer and painter input).
- Clipping readings are drawn in the error colour (widget test).
- With reduced motion enabled the widget does not animate (widget test).
- The Record screen renders without overflow at text scale 2.0 in light and dark, and the Record golden is updated.
- Painting a full buffer does not rebuild the rest of the screen (`RepaintBoundary` present; widget test).
