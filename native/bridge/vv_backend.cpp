// [STT-02] Backend loading/description and CPU topology for the C ABI.
// ggml APIs verified at llama.cpp v0.6.0 ggml (ggml-backend.h: ggml_backend_load,
// ggml_backend_dev_*; ggml-backend-reg.cpp: modules export ggml_backend_score).
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <vector>

#include "ggml-backend.h"
#include "vv_bridge.h"
#include "vv_cpu.h"

#if defined(VV_GGML_BACKENDS) && !defined(_WIN32)
#include <dlfcn.h>
#define VV_DL 1
#else
#define VV_DL 0
#endif

namespace {

#if VV_DL
std::mutex g_mu;
bool g_cpu_loaded = false;
uint32_t g_gpu_loaded = 0;

std::vector<std::string> split(const char* csv) {
  std::vector<std::string> out;
  std::string cur;
  for (const char* p = csv; *p; ++p) {
    if (*p == ',') {
      if (!cur.empty()) out.push_back(cur);
      cur.clear();
    } else {
      cur += *p;
    }
  }
  if (!cur.empty()) out.push_back(cur);
  return out;
}

std::string self_dir() {
  Dl_info info;
  if (dladdr(reinterpret_cast<void*>(&vv_backends_load), &info) && info.dli_fname) {
    std::string p = info.dli_fname;
    const auto slash = p.find_last_of('/');
    if (slash != std::string::npos) return p.substr(0, slash);
  }
  return "";
}

// ggml names modules lib<target>.so on every non-Windows platform
// (backend_filename_prefix/extension in ggml-backend-reg.cpp).
std::string module_path(const std::string& dir, const std::string& target) {
  const std::string file = "lib" + target + ".so";
  return dir.empty() ? file : dir + "/" + file;
}

typedef int (*score_fn)(void);

// Score of a module without registering it (0 = unusable on this CPU/device).
int probe_score(const std::string& path) {
  void* h = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (!h) return -1;
  int s = 0;
  if (auto fn = reinterpret_cast<score_fn>(dlsym(h, "ggml_backend_score"))) s = fn();
  else s = 1;  // modules without a score function are always usable
  dlclose(h);
  return s;
}

bool load_best_cpu(const std::string& dir, const std::vector<std::string>& mods) {
  std::string best;
  int best_score = 0;
  for (const auto& m : mods) {
    if (m.rfind("ggml-cpu", 0) != 0) continue;
    const std::string p = module_path(dir, m);
    const int s = probe_score(p);
    if (s > best_score) {
      best_score = s;
      best = p;
    }
  }
  return !best.empty() && ggml_backend_load(best.c_str()) != nullptr;
}

// Loads one named non-CPU module if it was built and can be dlopen()ed here.
bool load_gpu(const std::string& dir, const std::vector<std::string>& mods, const char* target) {
  for (const auto& m : mods) {
    if (m != target) continue;
    const std::string p = module_path(dir, m);
    if (probe_score(p) <= 0) return false;  // missing driver / no device
    return ggml_backend_load(p.c_str()) != nullptr;
  }
  return false;
}
#endif

const char* type_name(enum ggml_backend_dev_type t) {
  switch (t) {
    case GGML_BACKEND_DEVICE_TYPE_CPU: return "cpu";
    case GGML_BACKEND_DEVICE_TYPE_GPU: return "gpu";
    case GGML_BACKEND_DEVICE_TYPE_IGPU: return "igpu";
    case GGML_BACKEND_DEVICE_TYPE_ACCEL: return "accel";
    default: return "other";
  }
}

void json_str(std::string* out, const char* s) {
  *out += '"';
  for (const char* p = s ? s : ""; *p; ++p) {
    const unsigned char c = static_cast<unsigned char>(*p);
    if (c == '"' || c == '\\') {
      *out += '\\';
      *out += static_cast<char>(c);
    } else if (c < 0x20) {
      char buf[8];
      std::snprintf(buf, sizeof(buf), "\\u%04x", c);
      *out += buf;
    } else {
      *out += static_cast<char>(c);
    }
  }
  *out += '"';
}

}  // namespace

extern "C" {

int32_t vv_backends_dynamic(void) { return VV_DL; }

int32_t vv_backends_load(const char* lib_dir, uint32_t gpu_mask) {
  try {
#if VV_DL
    std::lock_guard<std::mutex> lock(g_mu);
    const std::string dir = lib_dir ? std::string(lib_dir) : self_dir();
    const auto mods = split(VV_GGML_BACKENDS);
    // GPU modules first so devices enumerate GPU-before-CPU like ggml's own loader.
    struct {
      uint32_t bit;
      const char* target;
    } const gpus[] = {{VV_GPU_METAL, "ggml-metal"},
                      {VV_GPU_VULKAN, "ggml-vulkan"},
                      {VV_GPU_OPENCL, "ggml-opencl"}};
    for (const auto& g : gpus) {
      if ((gpu_mask & g.bit) && !(g_gpu_loaded & g.bit) && load_gpu(dir, mods, g.target))
        g_gpu_loaded |= g.bit;
    }
    if (!g_cpu_loaded) {
      g_cpu_loaded = load_best_cpu(dir, mods);
      // CPU-side accelerator (Accelerate/OpenBLAS) when built; never a GPU.
      if (g_cpu_loaded) load_gpu(dir, mods, "ggml-blas");
    }
    return g_cpu_loaded ? VV_OK : VV_E_BACKEND;
#else
    (void)lib_dir;
    (void)gpu_mask;
    return ggml_backend_dev_count() > 0 ? VV_OK : VV_E_BACKEND;
#endif
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_backends_describe(char* buf, size_t cap, size_t* needed) {
  try {
    std::string j = "[";
    for (size_t i = 0; i < ggml_backend_dev_count(); ++i) {
      ggml_backend_dev_t d = ggml_backend_dev_get(i);
      if (i) j += ',';
      j += "{\"name\":";
      json_str(&j, ggml_backend_dev_name(d));
      j += ",\"type\":";
      json_str(&j, type_name(ggml_backend_dev_type(d)));
      j += ",\"description\":";
      json_str(&j, ggml_backend_dev_description(d));
      j += '}';
    }
    j += ']';
    if (needed) *needed = j.size() + 1;
    if (!buf || cap < j.size() + 1) {
      if (buf && cap > 0) buf[0] = '\0';
      return VV_E_INVALID_ARG;
    }
    std::memcpy(buf, j.c_str(), j.size() + 1);
    return VV_OK;
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_cpu_perf_cores(void) {
  const int n = vv::perf_cores();
  return n > 0 ? n : 1;
}

}  // extern "C"
