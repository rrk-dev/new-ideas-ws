/*
 * Voice activity detection part of the VaultVoice C ABI (AUD-03), included by
 * vv_bridge.h. Wraps whisper.cpp's built-in Silero VAD (ggml model, e.g.
 * ggml-silero-v6.2.0.bin), verified against whisper.cpp v1.9.5
 * (include/whisper.h: whisper_vad_init_from_file_with_params,
 * whisper_vad_detect_speech_no_reset, whisper_vad_segments_from_samples —
 * segment times in centiseconds; the model runs on 512-sample windows =
 * 32 ms at 16 kHz). whisper.h never crosses this boundary.
 *
 * Two uses, never mixed on one handle:
 *  - file mode: vv_vad_segments() -> speech segments of WAV ranges (pipeline
 *    worker isolate; blocking, call off the UI isolate);
 *  - streaming: vv_vad_feed() during a recording, to *stop or pause* after
 *    configured silence. VAD never starts or resumes a recording (SEC-09).
 * A handle is not thread-safe: one caller at a time (calls are serialized by
 * an internal mutex, so misuse blocks instead of corrupting state).
 * Content-free: nothing here logs or returns audio or text.
 */
#ifndef VV_VAD_H
#define VV_VAD_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef VV_API
#define VV_API __attribute__((visibility("default")))
#endif

typedef struct vv_vad vv_vad;

#ifndef VV_AUDIO_RANGE_DEFINED
#define VV_AUDIO_RANGE_DEFINED
/* [start_ms, end_ms) of a 16 kHz PCM16 WAV file; end_ms < 0 = to the end. */
typedef struct vv_audio_range {
  const char* path;
  int64_t start_ms;
  int64_t end_ms;
} vv_audio_range;
#endif

typedef struct vv_vad_params {
  uint32_t struct_size;    /* = sizeof(vv_vad_params) */
  float threshold;         /* speech probability threshold, 0.5 */
  int32_t min_speech_ms;   /* shorter speech is dropped, 250 */
  int32_t min_silence_ms;  /* silence that ends a segment, 500 */
  int32_t speech_pad_ms;   /* padding around segments, 200 */
  float max_speech_s;      /* split longer segments; <= 0 = no limit */
  int32_t n_threads;       /* <= 0: 1 */
} vv_vad_params;

/* Result of one vv_vad_feed call. */
typedef struct vv_vad_feed_result {
  int32_t windows;         /* 32 ms windows completed by this call */
  int32_t speech_windows;  /* of those, probability >= threshold */
  float max_prob;          /* highest probability, -1 when windows == 0 */
} vv_vad_feed_result;

VV_API vv_vad_params vv_vad_default_params(void);

/* Loads the ggml Silero model (CPU; ~1 MB). Blocking.
 * VV_E_INVALID_ARG (NULL args / struct_size), VV_E_MODEL_LOAD, VV_E_OOM. */
VV_API int32_t vv_vad_create(const char* model_path, const vv_vad_params* params, vv_vad** out);

/* Speech segments of the concatenation of n ranges, as a JSON array on that
 * concatenated timeline in ms: [{"start_ms":0,"end_ms":1234},...].
 * *out_json is malloc'd: free with vv_free_string. Resets the streaming
 * state. VV_E_INVALID_ARG (bad args / not 16 kHz PCM16 WAV), VV_E_IO,
 * VV_E_OOM, VV_E_INTERNAL. */
VV_API int32_t vv_vad_segments(vv_vad* h, const vv_audio_range* ranges, size_t n,
                               char** out_json);

/* Streaming: appends n mono 16 kHz PCM16 samples and runs the model on every
 * complete 32 ms window (model state carries across calls; a partial window
 * waits for the next call). n == 0 is allowed. */
VV_API int32_t vv_vad_feed(vv_vad* h, const int16_t* pcm, size_t n, vv_vad_feed_result* out);

/* Clears the streaming state and any buffered partial window. */
VV_API void vv_vad_reset(vv_vad* h);

/* Frees the model. Safe on NULL. */
VV_API void vv_vad_destroy(vv_vad* h);

/* Content-free message for the last failure on h (or of the last
 * vv_vad_create when h is NULL). Valid until the next call on h. */
VV_API const char* vv_vad_last_error(vv_vad* h);

#ifdef __cplusplus
}
#endif

#endif /* VV_VAD_H */
