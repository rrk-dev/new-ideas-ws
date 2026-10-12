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

#ifdef __cplusplus
}
#endif

#endif /* VV_BRIDGE_H */
