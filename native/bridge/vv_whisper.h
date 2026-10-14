/*
 * STT part of the VaultVoice C ABI (STT-03). Included by vv_bridge.h — Dart
 * binds it through ffigen like the rest of the bridge. whisper.h never
 * crosses this boundary (vv-ffi-bridge). Verified against whisper.cpp v1.9.5
 * (include/whisper.h: whisper_context_params, whisper_full_params incl.
 * carry_initial_prompt, abort_callback, new_segment_callback).
 *
 * Threading: vv_stt_transcribe_* start a native worker thread and return
 * immediately; callbacks run on that thread (Dart: NativeCallable.listener).
 * One job per handle at a time (second call -> VV_E_BUSY).
 * Ownership: every vv_stt_segment passed to on_segment is heap-allocated and
 * owned by the callee, who must release it with vv_stt_free_segment() (the
 * native thread never touches it again). on_done is the last callback of a
 * job; after it the callbacks are never called again for that job.
 */
#ifndef VV_WHISPER_H
#define VV_WHISPER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef VV_API
#define VV_API __attribute__((visibility("default")))
#endif

typedef struct vv_stt vv_stt;

#ifndef VV_AUDIO_RANGE_DEFINED
#define VV_AUDIO_RANGE_DEFINED
/* [start_ms, end_ms) of a 16 kHz PCM16 WAV file; end_ms < 0 = to the end. */
typedef struct vv_audio_range {
  const char* path;
  int64_t start_ms;
  int64_t end_ms;
} vv_audio_range;
#endif

typedef struct vv_stt_init_params {
  uint32_t struct_size; /* = sizeof(vv_stt_init_params) */
  int32_t use_gpu;      /* 0 = CPU only (background / denylisted GPU) */
  int32_t flash_attn;
  int32_t gpu_device;
} vv_stt_init_params;

typedef struct vv_stt_params {
  uint32_t struct_size;           /* = sizeof(vv_stt_params) */
  const char* language;           /* "en", "de", "auto"; NULL = "en" */
  int32_t translate;              /* 0 (we never translate) */
  int32_t n_threads;              /* <= 0: performance cores capped at 4 */
  int32_t beam_size;              /* <= 1: greedy */
  float temperature;              /* 0.0 */
  float temperature_inc;          /* 0.2; 0 disables temperature fallback */
  const char* initial_prompt;     /* vocabulary hints; NULL = none */
  int32_t carry_initial_prompt;   /* 1: prompt in every 30 s window */
  int32_t no_context;             /* 1 */
  int32_t token_timestamps;       /* 1: fill vv_stt_segment.tokens */
  int32_t suppress_nst;           /* 1 */
  float entropy_thold;            /* 2.4 */
  float logprob_thold;            /* -1.0 */
  float no_speech_thold;          /* 0.6 */
  /* ---- AUD-03: whisper.cpp built-in Silero VAD (whisper_full params.vad,
   * verified against v1.9.5). Fields below are read only when struct_size
   * covers them (callers built against the STT-03 layout keep working).
   * With VAD, silence is skipped before decoding and every time reported
   * (segments, tokens) is mapped back to the original audio timeline. */
  const char* vad_model_path;     /* ggml Silero model; NULL/"" = no VAD */
  float vad_threshold;            /* 0.5 speech probability */
  int32_t vad_min_speech_ms;      /* 250 */
  int32_t vad_min_silence_ms;     /* 500 */
  int32_t vad_speech_pad_ms;      /* 200 */
} vv_stt_params;

/* struct_size of the STT-03 layout (before the VAD fields). */
#define VV_STT_PARAMS_V1_SIZE offsetof(vv_stt_params, vad_model_path)

typedef struct vv_stt_token {
  const char* text; /* UTF-8 piece */
  float p;          /* probability */
  int64_t t0_ms;    /* timeline ms (token_timestamps only, else -1) */
  int64_t t1_ms;
} vv_stt_token;

typedef struct vv_stt_segment {
  int32_t index;          /* 0.. within the job */
  int64_t t0_ms;          /* position in the concatenated input */
  int64_t t1_ms;
  int32_t t0_range;       /* range index containing t0 */
  int64_t t0_src_ms;      /* t0 in that range's file (range.start_ms + offset) */
  int32_t t1_range;
  int64_t t1_src_ms;
  float avg_logprob;      /* mean token log-probability (confidence) */
  float no_speech_prob;
  const char* text;       /* UTF-8 */
  int32_t n_tokens;
  vv_stt_token* tokens;   /* n_tokens entries, NULL when 0 */
} vv_stt_segment;

/* percent 0..100 */
typedef void (*vv_stt_progress_cb)(void* user, int32_t percent);
/* seg: owned by the callee -> vv_stt_free_segment(seg) */
typedef void (*vv_stt_segment_cb)(void* user, vv_stt_segment* seg);
/* status: VV_OK, VV_E_CANCELLED, VV_E_IO, VV_E_INVALID_ARG (bad audio),
 * VV_E_OOM, VV_E_BACKEND, VV_E_INTERNAL. audio_ms = input length,
 * process_ms = wall time of the job, n_segments = on_segment calls made
 * (lets a listener that receives events on several ports wait for all). */
typedef void (*vv_stt_done_cb)(void* user, int32_t status, int64_t audio_ms, int64_t process_ms,
                               int32_t n_segments);

typedef struct vv_stt_callbacks {
  vv_stt_progress_cb on_progress; /* optional */
  vv_stt_segment_cb on_segment;   /* optional */
  vv_stt_done_cb on_done;         /* required */
} vv_stt_callbacks;

VV_API vv_stt_init_params vv_stt_default_init_params(void);
VV_API vv_stt_params vv_stt_default_params(void);

/* Loads a ggml whisper model (blocking; call off the UI isolate).
 * VV_E_INVALID_ARG (NULL args/struct_size), VV_E_MODEL_LOAD, VV_E_OOM. */
VV_API int32_t vv_stt_create(const char* model_path, const vv_stt_init_params* params,
                             vv_stt** out);

/* Transcribes one whole WAV file asynchronously. */
VV_API int32_t vv_stt_transcribe_async(vv_stt* h, const char* wav_path, const vv_stt_params* params,
                                       vv_stt_callbacks cbs, void* user);

/* Transcribes the concatenation of n ranges (one window, STT-04) asynchronously.
 * Paths are copied; the array may be freed when this returns. */
VV_API int32_t vv_stt_transcribe_ranges(vv_stt* h, const vv_audio_range* ranges, size_t n,
                                        const vv_stt_params* params, vv_stt_callbacks cbs,
                                        void* user);

/* Requests cancellation of the running job; returns immediately. The job's
 * on_done reports VV_E_CANCELLED. No-op when idle. */
VV_API void vv_stt_cancel(vv_stt* h);

/* Cancels, waits for the worker thread and frees the model. Safe on NULL and
 * after cancel. Do not call from a callback. */
VV_API void vv_stt_destroy(vv_stt* h);

VV_API void vv_stt_free_segment(vv_stt_segment* seg);

/* Content-free message for the last failure on h (or of the last
 * vv_stt_create when h is NULL). Valid until the next call on h. */
VV_API const char* vv_stt_last_error(vv_stt* h);

#ifdef __cplusplus
}
#endif

#endif /* VV_WHISPER_H */
