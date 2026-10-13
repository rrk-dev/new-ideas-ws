// [STT-02] Host tests for vv_backends_* / vv_cpu_perf_cores (bridge/vv_backend.cpp).
// One mode per ctest so each starts with a fresh ggml registry:
//   backends_test cores        perf-core detection (fake sysfs trees)
//   backends_test cpu-only     gpu_mask = 0 -> CPU device only (DL builds)
//   backends_test gpu          gpu_mask = all -> GPU device registered when present
//   backends_test missing-dir  modules not found -> VV_E_BACKEND, no crash (DL builds)
//   backends_test describe     JSON + buffer contract
// [STT-02/AC2] cpu-only and missing-dir are the safe-CPU-fallback checks.
#include <sys/stat.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "vv_bridge.h"
#include "vv_cpu.h"

namespace {

int fail(const char* what) {
  std::fprintf(stderr, "FAIL: %s\n", what);
  return 1;
}

std::string describe() {
  size_t need = 0;
  vv_backends_describe(nullptr, 0, &need);
  std::vector<char> buf(need ? need : 1);
  if (vv_backends_describe(buf.data(), buf.size(), nullptr) != VV_OK) return "";
  return buf.data();
}

bool has(const std::string& s, const char* n) { return s.find(n) != std::string::npos; }

void write_freq(const std::string& root, int cpu, long khz) {
  std::string p = root + "/devices";
  mkdir(p.c_str(), 0700);
  p += "/system";
  mkdir(p.c_str(), 0700);
  p += "/cpu";
  mkdir(p.c_str(), 0700);
  p += "/cpu" + std::to_string(cpu);
  mkdir(p.c_str(), 0700);
  p += "/cpufreq";
  mkdir(p.c_str(), 0700);
  FILE* f = std::fopen((p + "/cpuinfo_max_freq").c_str(), "w");
  std::fprintf(f, "%ld\n", khz);
  std::fclose(f);
}

int cores() {
  // Snapdragon 8 Gen 2: 3x A510 2.0 GHz, 4x A710/A715 2.8 GHz, 1x X3 3.19 GHz -> 5.
  if (vv::perf_cores_from_freqs({2016000, 2016000, 2016000, 2803200, 2803200, 2803200, 2803200, 3187200}) != 5)
    return fail("8 Gen 2 layout");
  // Snapdragon 7 Gen 1: 4x A510 + 3x A710 + 1x A710 prime -> 4.
  if (vv::perf_cores_from_freqs({1804800, 1804800, 1804800, 1804800, 2361600, 2361600, 2361600, 2400000}) != 4)
    return fail("7 Gen 1 layout");
  // Mali device (e.g. Dimensity / Exynos 2+2+4) -> 4.
  if (vv::perf_cores_from_freqs({2000000, 2000000, 2000000, 2000000, 2600000, 2600000, 3050000, 3050000}) != 4)
    return fail("2+2+4 layout");
  if (vv::perf_cores_from_freqs({2000000, 2000000, 2000000, 2000000}) != 4) return fail("uniform cluster");
  if (vv::perf_cores_from_freqs({}) != 0) return fail("unknown topology");
  if (vv::perf_cores_from_freqs({0, 0}) != 0) return fail("unreadable freqs");

  char tmpl[] = "/tmp/vv_sysfs_XXXXXX";
  const char* root = mkdtemp(tmpl);
  if (!root) return fail("mkdtemp");
  const long freqs[] = {1800000, 1800000, 1800000, 1800000, 2400000, 2400000, 2400000, 3000000};
  for (int i = 0; i < 8; ++i) write_freq(root, i, freqs[i]);
  if (vv::read_core_max_freqs(root).size() != 8) return fail("sysfs read");
  if (vv::perf_cores(root) < 1) return fail("perf_cores(root)");
#if !defined(__APPLE__)
  if (vv::perf_cores(root) != 4) return fail("perf_cores from fake sysfs");
#endif
  if (vv_cpu_perf_cores() < 1) return fail("vv_cpu_perf_cores >= 1");
  std::printf("cores OK (this host: %d perf cores)\n", vv_cpu_perf_cores());
  return 0;
}

int cpu_only() {
  if (vv_backends_load(nullptr, 0) != VV_OK) return fail("CPU-only load");
  const std::string d = describe();
  if (!has(d, "\"type\":\"cpu\"")) return fail("no CPU device");
  if (vv_backends_dynamic() && (has(d, "\"type\":\"gpu\"") || has(d, "\"type\":\"igpu\"")))
    return fail("GPU module loaded although gpu_mask = 0");
  std::printf("cpu-only OK dynamic=%d %s\n", vv_backends_dynamic(), d.c_str());
  return 0;
}

int gpu() {
  if (vv_backends_load(nullptr, VV_GPU_METAL | VV_GPU_VULKAN | VV_GPU_OPENCL) != VV_OK)
    return fail("GPU load must still succeed (CPU always available)");
  const std::string d = describe();
  if (!has(d, "\"type\":\"cpu\"")) return fail("no CPU device");
#if defined(__APPLE__)
  if (!has(d, "MTL")) return fail("Metal device not registered on macOS");
#endif
  // Idempotent: a second call neither fails nor duplicates devices.
  if (vv_backends_load(nullptr, VV_GPU_METAL) != VV_OK) return fail("second load");
  if (describe() != d) return fail("second load changed the device list");
  std::printf("gpu OK %s\n", d.c_str());
  return 0;
}

int missing_dir() {
  if (!vv_backends_dynamic()) {
    std::printf("SKIP: static build (backends are linked in)\n");
    return 77;
  }
  if (vv_backends_load("/nonexistent/vv", VV_GPU_VULKAN | VV_GPU_OPENCL) != VV_E_BACKEND)
    return fail("missing modules must report VV_E_BACKEND");
  // The app can retry with the right directory afterwards.
  if (vv_backends_load(nullptr, 0) != VV_OK) return fail("retry with default dir");
  std::printf("missing-dir OK\n");
  return 0;
}

int describe_contract() {
  vv_backends_load(nullptr, 0);
  size_t need = 0;
  char tiny[4] = {'x', 'x', 'x', 'x'};
  if (vv_backends_describe(tiny, sizeof(tiny), &need) != VV_E_INVALID_ARG) return fail("small buffer");
  if (tiny[0] != '\0' || need <= sizeof(tiny)) return fail("small buffer contract");
  const std::string d = describe();
  if (d.size() + 1 != need || d.front() != '[' || d.back() != ']') return fail("json shape");
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
  const std::string m = argc > 1 ? argv[1] : "";
  if (m == "cores") return cores();
  if (m == "cpu-only") return cpu_only();
  if (m == "gpu") return gpu();
  if (m == "missing-dir") return missing_dir();
  if (m == "describe") return describe_contract();
  std::fprintf(stderr, "usage: backends_test {cores|cpu-only|gpu|missing-dir|describe}\n");
  return 64;
}
