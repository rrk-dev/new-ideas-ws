# ADR-AUD-03 — Voice activity detection: whisper.cpp's built-in Silero VAD

- **Status:** Proposed — the engineering choice is made; AC1/AC2 numbers come from the QA-02
  corpus on devices (docs/test-plans/device/AUD-03.md)
- **Date:** 2026-10-14
- **Task:** AUD-03
- **Deciders:** Claude Code (implementer); pending independent verifier and QA-02 numbers
- **Builds on:** ADR-FND-06-native-build (one ggml, whisper.cpp v1.9.5), ADR-AUD-01, ADR-MDL-01

## Question
Which VAD detects speech vs silence to (a) skip silence before STT (less compute, no
hallucinated text on silence), (b) store a speech timeline per recording, (c) auto-pause /
auto-stop a recording after silence — under AGENTS.md constraints: offline, Dart talks only to
`native/bridge`, iOS 16+ / Android 26+ arm64, no new runtime unless justified, license must allow
commercial redistribution, VAD may stop/pause but **never start or resume** a recording (SEC-09).

## Options
1. **whisper.cpp built-in Silero VAD (chosen).** At the pinned v1.9.5 `whisper.h` exposes
   `whisper_vad_init_from_file_with_params`, `whisper_vad_detect_speech_no_reset` (streaming,
   LSTM state kept), `whisper_vad_segments_from_samples` (centisecond segments) and
   `whisper_full_params.vad / vad_model_path / vad_params`, which skips silence inside
   `whisper_full` and maps segment and token times back to the original timeline
   (`whisper_full_get_segment_t0`, `whisper_full_get_token_t0`). Model:
   `ggml-silero-v6.2.0.bin`, 885 098 B, MIT (Silero VAD), HF `ggml-org/whisper-vad` @ 9ffd54a.
   Zero new native dependencies — it is already in the binary.
2. **Silero VAD ONNX via onnxruntime.** Same model family, but adds onnxruntime (~5–15 MB per
   ABI, a second inference runtime to build, update and audit) for no capability we lack.
3. **WebRTC VAD (GMM).** Tiny, no model file, but markedly weaker on noisy far-field meeting
   audio (frequent false speech on noise) and no timestamp mapping into whisper.
4. **Energy threshold in Dart.** Trivial, but fails on noise floors and music; unusable for
   hallucination suppression.

## Criteria (weights fixed before measuring)
| Criterion | Weight | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| Accuracy on noisy speech | 5 | ✅ Silero | ✅ Silero | ⚠️ | ❌ |
| Integration (no new runtime, timestamp mapping into whisper) | 4 | ✅ | ❌ | ⚠️ | ⚠️ |
| Binary/model size | 2 | ✅ +~1 MB model, 0 code | ❌ | ✅ | ✅ |
| License | 2 | MIT | MIT + runtime | BSD | — |
| Streaming cost (UI must stay smooth) | 2 | ✅ own isolate | ✅ | ✅ | ✅ |

## Evidence (host, Apple M-series, macOS, `native/build.sh host`, CPU only)
- `native/tests/vad_test.cpp` (ctest `vv_vad_*`, models from `tools/ci/fetch_test_models.sh`):
  - jfk.wav segments `[150–2440, 3100–4580, 5210–7850, 7990–11000] ms`; 10 s of digital silence →
    no segments.
  - Streaming: 11 s of speech fed in 1 s blocks → 343 windows of 32 ms, 231 speech, **24 ms CPU
    total** (~2 ms per second of audio).
  - `[AUD-03/AC2]` 30 s of low-level noise with VAD → **0 segments, no text**; 20 s silence + jfk +
    20 s silence → words found, all segment times in 20 150–30 580 ms (original timeline).
  - A caller using the STT-03 `vv_stt_params` layout (`struct_size = VV_STT_PARAMS_V1_SIZE`) still
    works and the VAD fields are not read.
- Speed: `vad_test bench` (jfk + 4/8/12 s pauses, 186 s, ~55 % speech) was run while ~10 other
  agents loaded the machine (load average 415): 7.1–20.3 s without VAD vs 8.1–20.4 s with VAD,
  i.e. **inconclusive**. AC1 (≥ 20 % less STT time, ≤ 1 pt WER) must be measured on the QA-02
  corpus on devices — not claimed here.

## Decision
- Bridge: new `vv_vad_*` C ABI (`native/bridge/vv_vad.h`): `create`, `segments` (file ranges →
  JSON ms), `feed` (streaming counts per 32 ms window), `reset`, `destroy`, `last_error`; VAD
  fields appended to `vv_stt_params` (`vad_model_path`, threshold, min speech/silence, pad) with
  forward-compatible `struct_size` handling. Token times now use the mapped
  `whisper_full_get_token_t0/t1` (identical without VAD). ABI version unchanged (additive).
- Parameters (vv-audio-capture): threshold 0.5, min speech 250 ms, min silence 500 ms, pad 200 ms.
- Pipeline (`TranscribeStep`): when a VAD model is installed (`models_installed.type = vad`) and
  `processing.skip_silence` is on (provisional default **on**), whisper skips silence per chunk
  and, with `PipelineEngines.vad` (`FfiVadEngine`), the chunk's speech spans are written to
  `speech_segments` (recording timeline) in the chunk's checkpoint transaction. The params hash
  includes the VAD mode so a resume never mixes modes. A VAD failure loses only the timeline.
- Recording: `SilenceWatcher` feeds the capture's own PCM (1 s blocks) to `VvVadStream` (model on
  its own isolate) and can only call `RecordingController.pauseForSilence()` (after
  `SilencePolicy.defaultAutoPause` = 2 min, `audio.auto_pause_on_silence`) or `stop(silence)`
  (`audio.silence_auto_stop`: off / 5 / 10 / 30 min, default off). It never starts or resumes; a
  silence pause ends only by a user tap; during it the stop deadline runs on the wall clock.
  Without the model both settings are inert (logged, content-free).
- Model delivery: `silero-vad-v6.2.0` (type `vad`, free) added to `tools/model-catalog/models.json`
  and the bundled signed catalog (re-signed with a second development key, see
  tools/model-catalog/README.md). The model is never committed.

## Consequences
- Silence skipping depends on the model being installed (≈ 0.9 MB download).
- whisper keeps the VAD context per whisper state (loaded once per STT model load).
- Open: confirm the `skip_silence` default and AC1/AC2 with QA-02; if VAD does not reduce STT time
  on devices, keep it for hallucination suppression only (AC2) or default it off.
