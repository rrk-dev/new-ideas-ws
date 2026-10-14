/*
 * VaultVoice LLM bridge (llama.cpp, ADR-LLM-01): backend configuration, GPU
 * device discovery and an on-device benchmark/probe. The streaming engine
 * (vv_llm_create / generate / cancel) is added by LLM-04 on top of the same
 * backend-selection code.
 *
 * Plain C only (vv-ffi-bridge): fixed-width types, struct_size first, every
 * fallible function returns VV_OK or a VV_E_* code from vv_error.h.
 * Verified against llama.cpp v0.6.0 (d812350) / ggml 0.26.0.
 */
#ifndef VV_LLAMA_H
#define VV_LLAMA_H

#include <stddef.h>
#include <stdint.h>

#include "vv_error.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef VV_API
#if defined(_WIN32)
#define VV_API __declspec(dllexport)
#else
#define VV_API __attribute__((visibility("default")))
#endif
#endif

/* Flash attention modes (mirror llama_flash_attn_type). */
#define VV_LLM_FLASH_ATTN_AUTO (-1)
#define VV_LLM_FLASH_ATTN_OFF 0
#define VV_LLM_FLASH_ATTN_ON 1

/* Bits in vv_llm_bench_result.fallbacks: what the backend chain had to drop. */
#define VV_LLM_FALLBACK_GPU_TO_CPU 1 /* GPU model load / context init failed -> CPU */
#define VV_LLM_FALLBACK_KV_TO_F16 2  /* q8_0 KV context init failed -> f16 KV */

/* How to run llama.cpp. Get defaults from vv_llm_default_backend_params(). */
typedef struct vv_llm_backend_params {
  int32_t struct_size; /* = sizeof(vv_llm_backend_params) */
  /* 1: offload every layer + KV to the GPU (Metal / Vulkan / OpenCL).
   * 0: CPU only — no GPU device is even attached (iOS forbids GPU work in the
   *    background; Android GPU backends that are not allowlisted). */
  int32_t use_gpu;
  /* GPU device index from vv_llm_gpu_device_info (allowlist choice), or -1 =
   * llama.cpp's default device selection. Ignored when use_gpu = 0. */
  int32_t gpu_device;
  int32_t kv_quant;   /* 1: q8_0 K/V cache (needs flash attention), 0: f16 */
  int32_t flash_attn; /* VV_LLM_FLASH_ATTN_* */
  int32_t n_ctx;      /* context tokens; must hold prompt + generation */
  int32_t n_batch;    /* logical = physical batch (prefill slice) */
  int32_t n_threads;  /* 0 = vv_cpu_perf_cores() */
  int32_t use_mmap;   /* 1: memory-map the GGUF (pages are clean, evictable) */
} vv_llm_backend_params;

/* Defaults: GPU on, default device, q8_0 KV, flash attention auto, n_ctx
 * 4096, n_batch 512, perf-core threads, mmap on. */
VV_API vv_llm_backend_params vv_llm_default_backend_params(void);

/* Number of performance CPU cores (Apple: hw.perflevel0.physicalcpu;
 * Linux/Android: cores faster than the slowest cpufreq cluster, i.e. big.LITTLE
 * "LITTLE" cores excluded; fallback half the online cores). >= 1. On
 * Linux/Android llama.cpp's worker threads are also restricted to these cores
 * (ggml threadpool cpumask). */
VV_API int32_t vv_cpu_perf_cores(void);

/* CPU feature bits. */
#define VV_CPU_FEATURE_NEON 1
#define VV_CPU_FEATURE_DOTPROD 2
#define VV_CPU_FEATURE_I8MM 4
#define VV_CPU_FEATURE_SVE 8

/* `runtime`: features this CPU reports (Android/Linux getauxval HWCAP,
 * Apple sysctl hw.optional.arm.*). `build`: features the ggml CPU kernels in
 * this library were compiled to *require* (GGML_CPU_ARM_ARCH; at the pin
 * ggml_cpu_has_dotprod/matmul_int8 are compile-time). Either pointer may be
 * NULL. Calling this never executes the optional instructions. */
VV_API int32_t vv_cpu_features(int32_t* runtime, int32_t* build);

/* 1 when every `build` feature is present at runtime, else 0: Dart must not
 * start whisper/llama on an unsupported CPU (SIGILL), ADR-LLM-03. */
VV_API int32_t vv_cpu_supported(void);

/* GPU / integrated-GPU devices registered in ggml (Metal, Vulkan, OpenCL). */
VV_API int32_t vv_llm_gpu_device_count(void);

/* Name (e.g. "MTL0", "Vulkan0", "GPUOpenCL") and description (driver/GPU
 * model, e.g. "Apple M3 Pro", "Adreno (TM) 750") of GPU device `index`,
 * NUL-terminated and truncated to the caller's buffers. Diagnostics and
 * allowlisting only — never content. */
VV_API int32_t vv_llm_gpu_device_info(int32_t index, char* name, size_t name_cap,
                                      char* description, size_t description_cap);

typedef struct vv_llm_bench_result {
  int32_t struct_size; /* = sizeof(vv_llm_bench_result), set by the caller */
  int32_t used_gpu;     /* effective after fallbacks */
  int32_t used_kv_quant;
  int32_t fallbacks;    /* VV_LLM_FALLBACK_* bits */
  int32_t n_threads;
  int32_t n_prompt;
  int32_t n_gen;
  double load_ms;       /* model load (cold for the first call in a process) */
  double ctx_init_ms;
  double prefill_tps;
  double decode_tps;
  uint64_t model_bytes;     /* tensor bytes reported by llama.cpp */
  uint64_t peak_mem_bytes;  /* process peak: iOS/macOS phys_footprint, Linux/Android VmHWM */
  uint64_t output_hash;     /* FNV-1a of the greedy tokens: determinism check */
} vv_llm_bench_result;

/* Loads `model_path` with `params` (falling back GPU -> CPU and q8_0 -> f16
 * KV when initialisation fails), prefills `n_prompt` synthetic tokens, then
 * greedily decodes `n_gen` tokens (end-of-generation banned) and frees
 * everything. Blocking and heavy: call from a background isolate / thread.
 * Returns VV_OK, VV_E_INVALID_ARG (null args, n_prompt + n_gen > n_ctx, bad
 * gpu_device), VV_E_MODEL_LOAD, VV_E_BACKEND (decode failed), VV_E_OOM. */
VV_API int32_t vv_llm_bench(const char* model_path, const vv_llm_backend_params* params,
                            int32_t n_prompt, int32_t n_gen, vv_llm_bench_result* out);

/* Current and peak memory of this process as the OS killers account it
 * (Apple phys_footprint; Linux/Android VmRSS / VmHWM). FND-07 metrics. */
VV_API int32_t vv_proc_memory(uint64_t* current_bytes, uint64_t* peak_bytes);

/* LLM-07: device RAM. `total` = physical RAM the OS reports (iOS/macOS
 * hw.memsize, Linux/Android MemTotal). `available` = what this process can
 * still allocate before the OS kills it: iOS os_proc_available_memory()
 * (jetsam headroom incl. the increased-memory-limit entitlement), macOS
 * free + inactive + purgeable pages, Linux/Android MemAvailable. */
VV_API int32_t vv_device_memory(uint64_t* total_bytes, uint64_t* available_bytes);

/* ---------------------------------------------------------------------
 * Streaming engine (LLM-04). One model + context per handle; one active
 * generation per handle (a second call returns VV_E_BUSY).
 * ------------------------------------------------------------------- */
typedef struct vv_llm vv_llm;

/* Loads the model with the LLM-02/03 fallback chain. Blocking (seconds):
 * call from a background isolate. `*out` must be destroyed with
 * vv_llm_destroy. */
VV_API int32_t vv_llm_create(const char* model_path, const vv_llm_backend_params* params,
                             vv_llm** out);

typedef struct vv_llm_info {
  int32_t struct_size; /* = sizeof(vv_llm_info), set by the caller */
  int32_t used_gpu;
  int32_t used_kv_quant;
  int32_t fallbacks; /* VV_LLM_FALLBACK_* */
  int32_t n_ctx;
  int32_t n_threads;
  double load_ms;
  uint64_t model_bytes;
} vv_llm_info;

VV_API int32_t vv_llm_get_info(vv_llm* h, vv_llm_info* out);

/* Exact token count of `text` (with BOS as generation would add it). */
VV_API int32_t vv_llm_count_tokens(vv_llm* h, const char* text, int32_t* out);

typedef struct vv_chat_msg {
  const char* role; /* "system" | "user" | "assistant" */
  const char* content;
} vv_chat_msg;

/* Applies the model's embedded chat template (GGUF metadata) and adds the
 * assistant prefix. `*out` is malloc'd: free with vv_free_string.
 * VV_E_INVALID_ARG when the model has no template llama.cpp supports. */
VV_API int32_t vv_llm_apply_chat_template(vv_llm* h, const vv_chat_msg* msgs, size_t n,
                                          char** out);

VV_API void vv_free_string(char* s);

/* Sampling + limits for one generation. Get defaults (structured-extraction
 * preset) from vv_llm_default_gen_params(). temperature <= 0 = greedy. */
typedef struct vv_gen_params {
  int32_t struct_size; /* = sizeof(vv_gen_params) */
  int32_t n_predict;   /* hard cap on generated tokens */
  uint32_t seed;
  float temperature;
  int32_t top_k;      /* <= 0 disables */
  float top_p;        /* >= 1 disables */
  float min_p;        /* <= 0 disables */
  float repeat_penalty; /* 1.0 disables (never for JSON) */
  int32_t repeat_last_n;
  /* GBNF grammar (root rule "root") or NULL = unconstrained. Copied. */
  const char* grammar;
  /* Token callback batching: emit after this many tokens or 50 ms. */
  int32_t token_batch;
  /* VV_LLM_GRAMMAR_LAZY (default, LLM-05): check the grammar only against the
   * sampled token and mask the full vocabulary only when it is rejected.
   * VV_LLM_GRAMMAR_FULL: mask every candidate every step (reference). */
  int32_t grammar_mode;
  /* LLM-06 KV prefix reuse: 1 = keep the KV cache entries of the longest
   * token prefix this prompt shares with the previous run on this handle
   * (llama_memory_seq_rm from that position) and prefill only the rest;
   * 0 (default) = clear the KV cache first. Falls back to a full clear when
   * the memory cannot drop a partial sequence (recurrent models) or has
   * pruned early positions (SWA caches). Map-reduce chunks share the system
   * prompt + instructions prefix. */
  int32_t reuse_prefix;
} vv_gen_params;

#define VV_LLM_GRAMMAR_LAZY 0
#define VV_LLM_GRAMMAR_FULL 1

VV_API vv_gen_params vv_llm_default_gen_params(void);

/* LLM-06: prompt tokens the last generation on `h` took from the KV cache
 * instead of prefilling (0 without reuse_prefix). Call after on_done. */
VV_API int32_t vv_llm_last_reused_tokens(vv_llm* h, int32_t* out);

/* Text callback: `text` is malloc'd UTF-8 (whole code points only); the
 * receiver owns it and must call vv_free_string. Called on the engine's
 * worker thread (Dart: NativeCallable.listener). */
typedef void (*vv_llm_text_cb)(void* user, char* text);

/* Completion: status VV_OK (EOG or n_predict reached), VV_E_CANCELLED,
 * VV_E_INVALID_ARG (prompt does not fit n_ctx - n_predict, bad grammar),
 * VV_E_BACKEND (decode failed, e.g. iOS refused GPU work in the background
 * -> reload with use_gpu = 0), VV_E_OOM, VV_E_INTERNAL. Always called exactly
 * once per accepted generate_async, after the last text callback.
 * `n_chunks` = number of on_text calls made: receivers whose callbacks may be
 * delivered out of order (separate Dart ports) wait until they have seen
 * that many chunks. */
typedef void (*vv_llm_done_cb)(void* user, int32_t status, int32_t n_chunks, int32_t n_prompt,
                               int32_t n_gen, double prefill_ms, double decode_ms);

typedef struct vv_llm_callbacks {
  vv_llm_text_cb on_text;
  vv_llm_done_cb on_done;
  void* user;
} vv_llm_callbacks;

/* Starts generation of `prompt` (already chat-templated) on a native
 * worker thread and returns immediately: VV_OK, VV_E_BUSY,
 * VV_E_INVALID_ARG (bad args / grammar does not parse). The KV cache is
 * cleared first unless params->reuse_prefix is set. */
VV_API int32_t vv_llm_generate_async(vv_llm* h, const char* prompt, const vv_gen_params* params,
                                     vv_llm_callbacks callbacks);

/* Requests cancellation; returns immediately. The worker stops at the next
 * token / prefill slice and reports VV_E_CANCELLED via on_done. */
VV_API void vv_llm_cancel(vv_llm* h);

/* Cancels any running generation, waits for it, frees model + context.
 * Safe on NULL and after cancel. */
VV_API void vv_llm_destroy(vv_llm* h);

/* LLM-05: converts a JSON Schema (UTF-8 JSON text) to a GBNF grammar with
 * root rule "root" (llama.cpp json-schema-to-grammar). `*out_gbnf` is
 * malloc'd: free with vv_free_string. VV_E_INVALID_ARG when the input is not
 * JSON or the schema cannot be converted. Pure CPU, no model needed; call
 * when a profile is saved (cache the result), not per run. */
VV_API int32_t vv_json_schema_to_gbnf(const char* schema_json, char** out_gbnf);

#ifdef __cplusplus
}
#endif

#endif /* VV_LLAMA_H */
