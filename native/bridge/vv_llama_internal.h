// Internal C++ helpers shared by vv_llama.cpp (backend selection, bench) and
// vv_llama_engine.cpp (LLM-04 streaming engine). Never exposed to Dart.
#pragma once

#include <chrono>
#include <cstdint>
#include <vector>

#include "ggml-backend.h"
#include "ggml-cpu.h"
#include "llama.h"
#include "vv_llama.h"

namespace vv_internal {

using clk = std::chrono::steady_clock;

double ms_since(clk::time_point t0);

// Process memory as the OS low-memory killers account it (Apple:
// phys_footprint incl. Metal buffers; Linux/Android: VmRSS / VmHWM).
uint64_t current_mem_bytes();
uint64_t peak_mem_bytes();

void ensure_backend();
std::vector<ggml_backend_dev_t> gpu_devices();

// The loaded model + context, after the fallback chain. Frees everything.
struct Loaded {
  llama_model* model = nullptr;
  llama_context* ctx = nullptr;
  int32_t used_gpu = 0;
  int32_t used_kv_quant = 0;
  int32_t fallbacks = 0;
  int32_t n_threads = 0;
  double load_ms = 0;
  double ctx_ms = 0;
  ggml_threadpool* pool = nullptr;
  Loaded() = default;
  Loaded(const Loaded&) = delete;
  Loaded& operator=(const Loaded&) = delete;
  ~Loaded() {
    if (ctx) llama_free(ctx);
    if (pool) ggml_threadpool_free(pool);
    if (model) llama_model_free(model);
  }
};

// Resolves params.gpu_device, then loads GPU -> CPU and q8_0 -> f16 KV.
// Returns VV_OK, VV_E_INVALID_ARG (bad gpu_device) or VV_E_MODEL_LOAD.
int32_t open_model(const char* path, const vv_llm_backend_params& p, Loaded& out);

}  // namespace vv_internal
