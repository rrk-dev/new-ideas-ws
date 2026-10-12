---
name: vv-whisper-stt
description: "whisper.cpp speech-to-text usage: model variants/tiers, whisper_full params, long-form windowing with resume, timestamps, hallucination guards, vocabulary prompts, speaker diarization without voiceprints, transcript viewer/editor. Use for transcription code."
---

# Whisper STT

Build/backends: `vv-native-build`. ABI: `vv-ffi-bridge`. This skill = how to use whisper well.

## API usage (verify names in `native/whisper.cpp/include/whisper.h` at the pinned commit)
- Init: `whisper_context_default_params()` → set `use_gpu` (false when backgrounded or on
  denylisted GPU), `flash_attn` if supported → `whisper_init_from_file_with_params(path, cparams)`.
- Run: `whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH or GREEDY)` then `whisper_full(ctx, p, pcm_f32, n)`.
  Convert PCM16 → float `x / 32768.0f`.
- Read: `whisper_full_n_segments`, `whisper_full_get_segment_text`, `…_t0/_t1`
  (**units of 10 ms** → multiply by 10 for ms), `whisper_full_get_segment_no_speech_prob`,
  token probs via `whisper_full_get_token_data` for avg logprob / low-confidence highlighting.
- Callbacks: `new_segment_callback` (stream segments), `progress_callback`,
  `abort_callback` (checks the bridge's atomic cancel flag).

## Default parameters (tune with QA-02; record final values in `docs/models.md`)
| Param | Default | Why |
|---|---|---|
| strategy | greedy on Low tier, beam (size 5) on Mid/High | speed vs accuracy |
| language | `"en"` for `.en` models; user setting or `"auto"` for multilingual | |
| translate | false | |
| n_threads | perf cores (≤ 4 typical) | more threads ≠ faster on big.LITTLE |
| no_context | true (we pass our own prompt per window) | avoids runaway context errors |
| initial_prompt + `carry_initial_prompt = true` | profile vocabulary + tail (~200 chars) of previous window | continuity + names in **every** 30 s decode window (default false = first window only) |
| temperature / temperature_inc | 0.0 / 0.2 | fallback on failure |
| entropy_thold / logprob_thold / no_speech_thold | 2.4 / −1.0 / 0.6 | Whisper defaults |
| `suppress_blank`, `suppress_nst` | true | (`suppress_nst` defaults false) |
| token_timestamps | true when diarization or word highlighting needed | |

## Long-form windowing (STT-04)
1. Input: chunk WAVs + `speech_segments` from VAD.
2. Build windows of 30–120 s of **speech** (skip silence > 2 s), cut only inside silences.
   Keep a mapping table window-local ms → recording ms (accounts for removed silence). If
  whisper's built-in `params.vad` is on instead, segment `t0/t1` are already on the original
  timeline — don't map twice (`whisper_token_data.t0/t1` are *not* mapped).
3. Audio hand-off: the Dart side passes the window as a list of ranges
   `vv_audio_range {const char* path; int64 start_ms; int64 end_ms;}` to
   `vv_stt_transcribe_ranges(h, ranges, n, params, callbacks, user)`; native code reads/decrypts
   (codec per `vv-audio-capture` → Chunk writer) and concatenates the PCM — no temp WAV files.
   Per window: run `whisper_full`, map segment times back, insert `transcript_segments`
   in one transaction, update job checkpoint `{nextWindow}`.
4. Near-real-time mode: while recording, run windows as soon as their audio + trailing
   silence are on disk (only when device tier ≥ Mid and on power or > 50% battery). While the app is backgrounded on
   iOS this must use the **CPU** backend (no Metal in background — `vv-background-execution`).
5. Guards — drop or flag a segment when: `no_speech_prob > 0.6 && avg_logprob < −1.0`;
   text is a known hallucination ("Thank you for watching", "Subtitles by…", lone "you");
   repetition: same 3-gram ≥ 4× in a segment or segment identical to previous one;
   zlib compression ratio > 2.4. Unit-test each guard.

## Models & tiers (STT-07)
Files from the whisper.cpp model repo (ggml format): `ggml-tiny.en`, `ggml-base.en`,
`ggml-small.en`, `ggml-large-v3-turbo` (multilingual only) and their quantized variants
(`-q5_1`, `-q8_0`, `-q5_0`). Mirror to our CDN via `vv-model-delivery`; never download from
third-party URLs at runtime.
| Tier | Free | Pro |
|---|---|---|
| Low (< 5 GB) | tiny.en / base.en q5_1 | small.en q5_1 |
| Mid | base.en q5_1 | small.en q8_0 |
| High | base.en | large-v3-turbo q5_0 (multilingual) or small.en |
| Multilingual (any tier) | `ggml-base-q5_1` (multilingual base) | `ggml-small-q5_1` / large-v3-turbo q5_0 (High) |
Benchmarks (WER, RTF, peak RAM) decide the final table (`vv-benchmark-eval`). Entitlement
check via `EntitlementService` (`vv-licensing-iap`).

## Diarization (STT-05)
- Spike first (ADR): **sherpa-onnx offline speaker diarization** (pyannote segmentation +
  speaker-embedding model, has Flutter bindings `sherpa_onnx`) vs whisper.cpp tinydiarize
  (only `small.en-tdrz`, turn detection without identity) vs embedding + agglomerative
  clustering ourselves. Check model licenses (some pyannote models are gated) and onnxruntime
  size impact (REL-03).
- Integration: per AGENTS.md, Dart calls only `vv_bridge`. Compile the sherpa-onnx **C API**
  (and onnxruntime) into `vv_native` and expose `vv_diar_*` (see `vv-ffi-bridge`), rather than
  using the `sherpa_onnx` Dart package directly — unless the STT-05 ADR approves an exception and
  AGENTS.md is updated. Diarization models ship via the model catalog (`diarization-seg`,
  `diarization-emb`).
- Run as a separate pipeline step after STT on the same audio (never concurrently with LLM).
- Alignment: assign each transcript segment the speaker with maximum time overlap; if a segment
  spans a speaker change > 1 s, split at the nearest token timestamp.
- Speakers table: `Speaker 1..N`; renames (`display_name`) flow into prompts and Markdown.
- Option "number of speakers" (auto / 2–8) improves clustering; off for warranty profile.
- **No voice enrollment/voiceprints**: embeddings are biometric data — keep them in memory
  only for clustering, never write them to disk/DB, free them when the step ends (test this).
- Metric: DER on AMI subset (`vv-benchmark-eval`), target ≤ 20%.

## Transcript viewer/editor (STT-06)
Segment list (speaker chip, timestamp, text), tap → `just_audio` (a `StreamAudioSource` over the chunk reader, so encrypted chunks decrypt on
the fly) seek to `start_ms` across chunk
files (concatenating source or a playlist), current segment highlight from player position,
inline edit (sets `transcripts.edited = true`, keeps original in history), find & replace
(scoped to this transcript), low-confidence tokens underlined (prob < 0.5), "Re-extract" →
pipeline `rerun(fromStep: extract)`.

## Verification
- Integration test on device with `ggml-tiny.en` + fixture clip: keyword match, timestamps
  monotonic, within ±250 ms of known word times.
- 2 h recording: peak RAM flat across windows; kill/resume produces no duplicate segments.
