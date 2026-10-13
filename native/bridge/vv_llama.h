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

#ifdef __cplusplus
}
#endif

#endif /* VV_LLAMA_H */
