---
name: vv-ffi-bridge
description: "The C ABI bridge (native/bridge/vv_bridge.h) and Dart FFI side: opaque handles, error codes, memory ownership, native worker threads, NativeCallable.listener callbacks, cancellation, ffigen, library loading. Use when exposing any native function to Dart."
---

# C ABI Bridge & Dart FFI

Dart talks **only** to `native/bridge/vv_bridge.h`. Never bind whisper.h / llama.h directly:
their APIs change frequently, use C++ types, and would leak into Dart.

## C ABI rules
- Pure C header (`extern "C"`), prefix `vv_`, `VV_API` visibility macro.
- **Opaque handles**: `typedef struct vv_stt vv_stt;` created by `vv_stt_create(...)`,
  destroyed by `vv_stt_destroy(h)`. Destroy must be safe to call once after cancel.
- **Errors**: every fallible function returns `int32_t` (`VV_OK = 0`, negative codes in
  `vv_error.h`: `VV_E_INVALID_ARG, VV_E_MODEL_LOAD, VV_E_OOM, VV_E_CANCELLED, VV_E_IO,
  VV_E_BACKEND, VV_E_BUSY, VV_E_INTERNAL`). `const char* vv_last_error(handle)` returns a thread-local or
  per-handle message valid until the next call on that handle.
- **No exceptions cross the ABI**: wrap every C++ body in `try { … } catch (const std::bad_alloc&)
  { return VV_E_OOM; } catch (...) { return VV_E_INTERNAL; }`.
- **Strings**: UTF-8, NUL-terminated. Inputs are borrowed for the call duration. Outputs either
  written into caller buffer (`char* buf, size_t cap, size_t* needed`) or returned as
  `char*` that the caller frees with `vv_free_string(char*)`. Never return pointers into
  internal C++ objects.
- **Structs**: plain C structs with fixed-width types, `struct_size` first field for forward
  compatibility (`params.struct_size = sizeof(params)`), provide `vv_*_default_params()`.
- **Audio input**: pass file paths (chunk WAVs) rather than PCM buffers from Dart to avoid copying
  hours of audio across FFI. Native reads/decodes 16 kHz mono PCM.
- **Threading**: long operations are async: `vv_stt_transcribe_async(h, path, params, cb, user)`
  spawns/uses a native worker thread and returns immediately. One active job per handle;
  second call returns `VV_E_BUSY`.
- **Cancellation**: `vv_*_cancel(h)` sets a `std::atomic<bool>`; whisper `abort_callback` /
  llama generation loop checks it. Cancel returns immediately; completion callback later
  reports `VV_E_CANCELLED`. Never implement abort as a Dart callback (the only synchronous any-thread option,
  `NativeCallable.isolateGroupBound`, is experimental).

## Callbacks (Dart ≥ 3.1)
- Use `NativeCallable<…>.listener(dartFn)` for progress, segment, token and completion events.
  Listener callbacks are async, return `void`, may be invoked from any native thread.
- Callback payloads: copy data into a malloc'd struct/string, pass pointer + `user_data`;
  the Dart side copies it into Dart objects and then calls `vv_free_*`. Document ownership on
  every callback typedef.
- Keep the `NativeCallable` alive until the completion callback fires, then `close()` it.
- Batch token callbacks (e.g. every 4 tokens or 50 ms) to limit isolate message traffic.

## Dart side (`packages/vv_native/lib/`)
- `ffigen.yaml` → `lib/src/vv_bridge_bindings.g.dart` (committed). Regenerate with
  `fvm dart run ffigen --config ffigen.yaml` whenever the header changes.
- Loader:
  ```dart
  DynamicLibrary _open() => Platform.isAndroid
      ? DynamicLibrary.open('libvv_native.so')
      : Platform.isIOS
          ? DynamicLibrary.open('vv_native.framework/vv_native') // or .process() if static
          : DynamicLibrary.open(_hostLibPath());                // tests / tools
  ```
- Public API is idiomatic Dart: `Stream<SttEvent> transcribe(...)`, `Future<void> cancel()`,
  classes implementing `SttEngine` / `LlmEngine` from `vv-flutter-architecture`.
- Use `Arena` (`using((arena) { … })`) for temporary allocations; never leak `toNativeUtf8()`.
- Map `int32_t` codes → `Failure` in one function.
- Finalizers: attach `NativeFinalizer` to handle wrappers as a safety net, but always destroy
  explicitly (unload models deterministically for memory reasons).

## Required bridge functions (minimum)
```
int32_t vv_version(char* buf, size_t cap);
int32_t vv_system_info(char* buf, size_t cap);          // backends, CPU features
int32_t vv_device_memory(uint64_t* total, uint64_t* available);
// STT
vv_stt_params vv_stt_default_params(void);
int32_t vv_stt_create(const char* model_path, const vv_stt_init_params*, vv_stt** out);
int32_t vv_stt_transcribe_async(vv_stt*, const char* wav_path, const vv_stt_params*, vv_stt_callbacks, void* user);
void    vv_stt_cancel(vv_stt*);  void vv_stt_destroy(vv_stt*);
// LLM
int32_t vv_llm_create(const char* model_path, const vv_llm_init_params*, vv_llm** out);
int32_t vv_llm_count_tokens(vv_llm*, const char* text, int32_t* out);
int32_t vv_llm_apply_chat_template(vv_llm*, const vv_chat_msg* msgs, size_t n, char** out);
int32_t vv_llm_generate_async(vv_llm*, const char* prompt, const vv_gen_params*, vv_llm_callbacks, void* user);
void    vv_llm_cancel(vv_llm*);  void vv_llm_destroy(vv_llm*);
void    vv_free_string(char*);
// STT with window ranges (STT-04) and optional file key (SEC-01 vvenc codec)
typedef struct { const char* path; int64_t start_ms; int64_t end_ms; } vv_audio_range;
int32_t vv_stt_transcribe_ranges(vv_stt*, const vv_audio_range*, size_t n, const vv_stt_params*, vv_stt_callbacks, void* user);
int32_t vv_key_create(const uint8_t* key, size_t len, vv_key** out); void vv_key_destroy(vv_key*);
// vv_stt_params.key / vv_vad params may reference a vv_key* (NULL = plaintext WAV)
// LLM grammar: vv_gen_params.grammar (GBNF, NULL = unconstrained), .n_predict, .seed, sampler preset
int32_t vv_json_schema_to_gbnf(const char* schema_json, char** out_gbnf);
// VAD (AUD-03): file-based + streaming (auto-stop on silence during recording — never auto-start)
int32_t vv_vad_create(const char* model_path, const vv_vad_params*, vv_vad** out);
int32_t vv_vad_segments(vv_vad*, const vv_audio_range*, size_t n, char** out_json); // [{start_ms,end_ms}]
int32_t vv_vad_feed(vv_vad*, const int16_t* pcm, size_t n, float* out_speech_prob);  // streaming
void    vv_vad_destroy(vv_vad*);
// Diarization (STT-05) — embeddings stay inside native memory, never returned or persisted
int32_t vv_diar_create(const char* seg_model, const char* emb_model, const vv_diar_params*, vv_diar** out);
int32_t vv_diar_run_async(vv_diar*, const vv_audio_range*, size_t n, vv_diar_callbacks, void* user); // turns JSON
void    vv_diar_cancel(vv_diar*); void vv_diar_destroy(vv_diar*);
// Metrics (FND-07): peak/current resident memory of this process
int32_t vv_proc_memory(uint64_t* current_bytes, uint64_t* peak_bytes);
```

## Tests
- C: `packages/vv_native/test/native/` ctest — create/destroy, invalid path → `VV_E_MODEL_LOAD`,
  cancel mid-run → `VV_E_CANCELLED`, ASan/UBSan build on host (`-fsanitize=address,undefined`).
- Dart: host-library FFI tests (load host build), leak check by running create/destroy 100×
  and asserting RSS returns to baseline (± tolerance).
