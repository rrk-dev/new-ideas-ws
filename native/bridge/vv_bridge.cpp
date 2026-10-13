#include "vv_bridge.h"

#include "ggml.h"
#include "llama.h"
#include "whisper.h"

#define VV_BRIDGE_SEMVER "0.1.0"

extern "C" {

int32_t vv_abi_version(void) { return VV_ABI_VERSION; }

const char* vv_version(void) { return VV_BRIDGE_SEMVER; }

const char* vv_whisper_version(void) { return whisper_version(); }

const char* vv_ggml_version(void) { return ggml_version(); }

const char* vv_whisper_system_info(void) { return whisper_print_system_info(); }

const char* vv_llama_system_info(void) { return llama_print_system_info(); }

}  // extern "C"
