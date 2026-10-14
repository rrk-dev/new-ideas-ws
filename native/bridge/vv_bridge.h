/*
 * VaultVoice native bridge: the ONLY C ABI Dart talks to (AGENTS.md).
 *
 * Rules (vv-ffi-bridge): plain C types only, no C++ across the boundary,
 * opaque handles, every function prefixed `vv_`, strings returned by the
 * library are static (never freed by the caller). Bump VV_ABI_VERSION on any
 * breaking change; Dart checks it at load time.
 */
#ifndef VV_BRIDGE_H
#define VV_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define VV_API __declspec(dllexport)
#else
#define VV_API __attribute__((visibility("default")))
#endif

#define VV_ABI_VERSION 1

/* ABI revision of this header. Dart refuses to run on a mismatch. */
VV_API int32_t vv_abi_version(void);

/* "<bridge semver>" of this library, e.g. "0.1.0". Static string. */
VV_API const char* vv_version(void);

/* Pinned upstream versions linked into this build. Static strings. */
VV_API const char* vv_whisper_version(void);
VV_API const char* vv_ggml_version(void);

/* Backend/CPU feature summaries (diagnostics only, never content). Static
 * strings owned by the respective library. */
VV_API const char* vv_whisper_system_info(void);
VV_API const char* vv_llama_system_info(void);

/* ---- Backends & CPU (STT-02, shared by STT and LLM) ---------------------
 * Error codes: vv_error.h. */
#include "vv_error.h"

/* GPU backend families for vv_backends_load(gpu_mask). */
#define VV_GPU_METAL 0x1u
#define VV_GPU_VULKAN 0x2u
#define VV_GPU_OPENCL 0x4u

/* Loads the ggml backends once per process; call before vv_stt_create /
 * vv_llm_create. In a VV_GGML_BACKEND_DL build it dlopen()s the best CPU
 * variant for this CPU plus each GPU module whose bit is set in gpu_mask
 * (the Dart allowlist decides the mask; 0 = CPU only). Later calls may add
 * GPU families but never unload. In a static build (iOS, default Android)
 * every compiled backend is already registered and this is a no-op; choose
 * CPU-only per model with use_gpu = 0 instead.
 * lib_dir: directory of the backend modules; NULL = the directory of this
 * library (works for extracted and APK-embedded Android libs).
 * Returns VV_OK, or VV_E_BACKEND when no CPU backend could be loaded. */
VV_API int32_t vv_backends_load(const char* lib_dir, uint32_t gpu_mask);

/* JSON array describing the registered devices (diagnostics +
 * DeviceCapabilities; hardware names only, never content):
 * [{"name":"CPU","type":"cpu","description":"..."},{"name":"Vulkan0","type":"gpu",...}]
 * Writes up to cap bytes incl. NUL into buf; *needed (optional) receives the
 * full size incl. NUL. Returns VV_OK, or VV_E_INVALID_ARG when cap is too
 * small (buf then holds an empty string if cap > 0). */
VV_API int32_t vv_backends_describe(char* buf, size_t cap, size_t* needed);

/* 1 when this library was built with runtime-loaded backends. */
VV_API int32_t vv_backends_dynamic(void);

#ifdef __cplusplus
}
#endif

#endif /* VV_BRIDGE_H */
