// VaultVoice LLM bridge: backend selection + benchmark probe (LLM-02/LLM-03).
// API verified against llama.cpp v0.6.0 (d812350) include/llama.h and
// ggml/include/ggml-backend.h: model_params.load_mode (use_mmap is gone),
// model_params.devices (NULL-terminated; an empty list = no GPU at all),
// flash_attn_type enum, type_k/type_v, llama_batch_get_one + llama_decode,
// llama_sampler_sample (samples AND accepts — never accept twice).
#include "vv_llama.h"

#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <new>
#include <string>
#include <thread>
#include <vector>

#if defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#endif

#include "ggml-backend.h"
#include "llama.h"

namespace {

using clk = std::chrono::steady_clock;

double ms_since(clk::time_point t0) {
  return std::chrono::duration<double, std::milli>(clk::now() - t0).count();
}

// Peak memory as the OS low-memory killers account it.
uint64_t peak_mem_bytes() {
#if defined(__APPLE__)
  task_vm_info_data_t info;
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS &&
      count >= TASK_VM_INFO_REV2_COUNT) {
    return info.ledger_phys_footprint_peak;  // includes Metal buffers (unified memory)
  }
  return 0;
#else
  FILE* f = fopen("/proc/self/status", "r");
  if (!f) return 0;
  char line[256];
  unsigned long long kb = 0;
  while (fgets(line, sizeof line, f)) {
    if (sscanf(line, "VmHWM: %llu kB", &kb) == 1) break;
  }
  fclose(f);
  return (uint64_t)kb * 1024;
#endif
}

void quiet_log(ggml_log_level level, const char* text, void*) {
  // Only backend errors; llama.cpp never logs prompt text at this level.
  if (level == GGML_LOG_LEVEL_ERROR) fputs(text, stderr);
}

void ensure_backend() {
  static bool done = [] {
    llama_log_set(quiet_log, nullptr);
    llama_backend_init();
    return true;
  }();
  (void)done;
}

std::vector<ggml_backend_dev_t> gpu_devices() {
  ensure_backend();
  std::vector<ggml_backend_dev_t> out;
  for (size_t i = 0; i < ggml_backend_dev_count(); i++) {
    ggml_backend_dev_t d = ggml_backend_dev_get(i);
    auto t = ggml_backend_dev_type(d);
    if (t == GGML_BACKEND_DEVICE_TYPE_GPU || t == GGML_BACKEND_DEVICE_TYPE_IGPU) out.push_back(d);
  }
  return out;
}

void copy_str(char* dst, size_t cap, const char* src) {
  if (!dst || cap == 0) return;
  snprintf(dst, cap, "%s", src ? src : "");
}

// The loaded model + context, after the fallback chain.
struct Loaded {
  llama_model* model = nullptr;
  llama_context* ctx = nullptr;
  int32_t used_gpu = 0;
  int32_t used_kv_quant = 0;
  int32_t fallbacks = 0;
  int32_t n_threads = 0;
  double load_ms = 0;
  double ctx_ms = 0;
  ~Loaded() {
    if (ctx) llama_free(ctx);
    if (model) llama_model_free(model);
  }
};

llama_model* load_model(const char* path, const vv_llm_backend_params& p, bool gpu,
                        ggml_backend_dev_t dev) {
  llama_model_params mp = llama_model_default_params();
  mp.load_mode = p.use_mmap ? LLAMA_LOAD_MODE_MMAP : LLAMA_LOAD_MODE_NONE;
  // devices: CPU mode passes an empty list so no GPU backend is attached at
  // all (iOS kills GPU submissions from the background).
  static ggml_backend_dev_t none[1] = {nullptr};
  thread_local ggml_backend_dev_t one[2] = {nullptr, nullptr};
  if (!gpu) {
    mp.n_gpu_layers = 0;
    mp.devices = none;
  } else {
    mp.n_gpu_layers = -1;  // all layers
    if (dev) {
      one[0] = dev;
      mp.devices = one;
    }
  }
  return llama_model_load_from_file(path, mp);
}

llama_context* init_ctx(llama_model* m, const vv_llm_backend_params& p, bool gpu, bool kvq,
                        int32_t threads) {
  llama_context_params cp = llama_context_default_params();
  cp.n_ctx = (uint32_t)p.n_ctx;
  cp.n_batch = cp.n_ubatch = (uint32_t)p.n_batch;
  cp.n_threads = cp.n_threads_batch = threads;
  cp.flash_attn_type = p.flash_attn == VV_LLM_FLASH_ATTN_ON    ? LLAMA_FLASH_ATTN_TYPE_ENABLED
                       : p.flash_attn == VV_LLM_FLASH_ATTN_OFF ? LLAMA_FLASH_ATTN_TYPE_DISABLED
                                                               : LLAMA_FLASH_ATTN_TYPE_AUTO;
  cp.type_k = cp.type_v = kvq ? GGML_TYPE_Q8_0 : GGML_TYPE_F16;
  cp.offload_kqv = gpu;
  cp.op_offload = gpu;  // CPU mode must not push batch ops to a GPU either
  cp.no_perf = true;
  return llama_init_from_model(m, cp);
}

// GPU -> CPU, then q8_0 KV -> f16. Returns VV_OK or VV_E_MODEL_LOAD.
int32_t open_with_fallbacks(const char* path, const vv_llm_backend_params& p,
                            ggml_backend_dev_t dev, Loaded& out) {
  out.n_threads = p.n_threads > 0 ? p.n_threads : vv_cpu_perf_cores();
  bool gpu = p.use_gpu != 0;
  for (;;) {
    auto t0 = clk::now();
    out.model = load_model(path, p, gpu, dev);
    out.load_ms = ms_since(t0);
    if (!out.model) {
      if (gpu) {
        gpu = false;
        out.fallbacks |= VV_LLM_FALLBACK_GPU_TO_CPU;
        continue;
      }
      return VV_E_MODEL_LOAD;
    }
    bool kvq = p.kv_quant != 0;
    t0 = clk::now();
    out.ctx = init_ctx(out.model, p, gpu, kvq, out.n_threads);
    if (!out.ctx && kvq) {
      // Quantized V needs flash attention; with FA off/unsupported init fails.
      kvq = false;
      out.fallbacks |= VV_LLM_FALLBACK_KV_TO_F16;
      out.ctx = init_ctx(out.model, p, gpu, kvq, out.n_threads);
    }
    out.ctx_ms = ms_since(t0);
    if (out.ctx) {
      out.used_gpu = gpu ? 1 : 0;
      out.used_kv_quant = kvq ? 1 : 0;
      return VV_OK;
    }
    llama_model_free(out.model);
    out.model = nullptr;
    if (!gpu) return VV_E_MODEL_LOAD;
    gpu = false;
    out.fallbacks |= VV_LLM_FALLBACK_GPU_TO_CPU;
  }
}

// Synthetic, content-free prompt of exactly n tokens.
std::vector<llama_token> synthetic_prompt(const llama_vocab* vocab, int32_t n) {
  static const char kText[] =
      " The team reviewed the release checklist, agreed on owners and dates, and"
      " noted open questions about battery tests and the device lab budget.";
  std::vector<llama_token> base(256);
  int k = llama_tokenize(vocab, kText, (int)strlen(kText), base.data(), (int)base.size(),
                         false, false);
  std::vector<llama_token> out;
  out.reserve(n);
  llama_token bos = llama_vocab_bos(vocab);
  if (bos != LLAMA_TOKEN_NULL && n > 0) out.push_back(bos);
  while ((int32_t)out.size() < n && k > 0) {
    for (int i = 0; i < k && (int32_t)out.size() < n; i++) out.push_back(base[i]);
  }
  return out;
}

int32_t bench_impl(const char* path, const vv_llm_backend_params& p, int32_t n_prompt,
                   int32_t n_gen, vv_llm_bench_result& r) {
  ggml_backend_dev_t dev = nullptr;
  if (p.use_gpu && p.gpu_device >= 0) {
    auto gpus = gpu_devices();
    if ((size_t)p.gpu_device >= gpus.size()) return VV_E_INVALID_ARG;
    dev = gpus[p.gpu_device];
  }
  ensure_backend();
  if (FILE* f = fopen(path, "rb")) {
    fclose(f);
  } else {
    return VV_E_MODEL_LOAD;  // unreadable file: no point trying GPU then CPU
  }
  Loaded L;
  int32_t rc = open_with_fallbacks(path, p, dev, L);
  if (rc != VV_OK) return rc;
  const llama_vocab* vocab = llama_model_get_vocab(L.model);

  llama_sampler* smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
  std::vector<llama_logit_bias> bans;
  const int nv = llama_vocab_n_tokens(vocab);
  for (llama_token t = 0; t < nv; t++)
    if (llama_vocab_is_eog(vocab, t)) bans.push_back({t, -INFINITY});
  llama_sampler_chain_add(smpl, llama_sampler_init_logit_bias(nv, (int)bans.size(), bans.data()));
  llama_sampler_chain_add(smpl, llama_sampler_init_greedy());

  std::vector<llama_token> prompt = synthetic_prompt(vocab, n_prompt);
  auto t0 = clk::now();
  for (size_t i = 0; i < prompt.size(); i += (size_t)p.n_batch) {
    int n = (int)std::min<size_t>((size_t)p.n_batch, prompt.size() - i);
    if (llama_decode(L.ctx, llama_batch_get_one(prompt.data() + i, n)) != 0) {
      llama_sampler_free(smpl);
      return VV_E_BACKEND;
    }
  }
  double prefill_ms = ms_since(t0);

  uint64_t hash = 1469598103934665603ULL;
  int32_t gen = 0;
  t0 = clk::now();
  for (; gen < n_gen; gen++) {
    llama_token tok = llama_sampler_sample(smpl, L.ctx, -1);  // already accepted
    hash = (hash ^ (uint64_t)(uint32_t)tok) * 1099511628211ULL;
    if (llama_decode(L.ctx, llama_batch_get_one(&tok, 1)) != 0) {
      llama_sampler_free(smpl);
      return VV_E_BACKEND;
    }
  }
  double decode_ms = ms_since(t0);
  llama_sampler_free(smpl);

  r.used_gpu = L.used_gpu;
  r.used_kv_quant = L.used_kv_quant;
  r.fallbacks = L.fallbacks;
  r.n_threads = L.n_threads;
  r.n_prompt = (int32_t)prompt.size();
  r.n_gen = gen;
  r.load_ms = L.load_ms;
  r.ctx_init_ms = L.ctx_ms;
  r.prefill_tps = prefill_ms > 0 ? prompt.size() / (prefill_ms / 1000.0) : 0;
  r.decode_tps = decode_ms > 0 ? gen / (decode_ms / 1000.0) : 0;
  r.model_bytes = llama_model_size(L.model);
  r.peak_mem_bytes = peak_mem_bytes();
  r.output_hash = hash;
  return VV_OK;
}

}  // namespace

extern "C" {

vv_llm_backend_params vv_llm_default_backend_params(void) {
  vv_llm_backend_params p;
  memset(&p, 0, sizeof p);
  p.struct_size = (int32_t)sizeof p;
  p.use_gpu = 1;
  p.gpu_device = -1;
  p.kv_quant = 1;
  p.flash_attn = VV_LLM_FLASH_ATTN_AUTO;
  p.n_ctx = 4096;
  p.n_batch = 512;
  p.n_threads = 0;
  p.use_mmap = 1;
  return p;
}

int32_t vv_cpu_perf_cores(void) {
#if defined(__APPLE__)
  int32_t n = 0;
  size_t len = sizeof n;
  if (sysctlbyname("hw.perflevel0.physicalcpu", &n, &len, nullptr, 0) == 0 && n > 0) return n;
#endif
  unsigned hc = std::thread::hardware_concurrency();
  return hc >= 2 ? (int32_t)(hc / 2) : 1;
}

int32_t vv_llm_gpu_device_count(void) {
  try {
    return (int32_t)gpu_devices().size();
  } catch (...) {
    return 0;
  }
}

int32_t vv_llm_gpu_device_info(int32_t index, char* name, size_t name_cap, char* description,
                               size_t description_cap) {
  try {
    auto gpus = gpu_devices();
    if (index < 0 || (size_t)index >= gpus.size()) return VV_E_INVALID_ARG;
    copy_str(name, name_cap, ggml_backend_dev_name(gpus[index]));
    copy_str(description, description_cap, ggml_backend_dev_description(gpus[index]));
    return VV_OK;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_llm_bench(const char* model_path, const vv_llm_backend_params* params, int32_t n_prompt,
                     int32_t n_gen, vv_llm_bench_result* out) {
  if (!model_path || !params || !out || params->struct_size != (int32_t)sizeof(*params) ||
      out->struct_size != (int32_t)sizeof(*out) || n_prompt < 1 || n_gen < 0 ||
      params->n_ctx < 1 || params->n_batch < 1 || (int64_t)n_prompt + n_gen > params->n_ctx) {
    return VV_E_INVALID_ARG;
  }
  try {
    vv_llm_bench_result r;
    memset(&r, 0, sizeof r);
    r.struct_size = (int32_t)sizeof r;
    int32_t rc = bench_impl(model_path, *params, n_prompt, n_gen, r);
    if (rc == VV_OK) *out = r;
    return rc;
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

}  // extern "C"
