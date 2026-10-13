// Internal (not part of the C ABI): performance-core detection for thread
// tuning (STT-02, vv-native-build "Threads: pin to performance cores").
// Header-only so the host tests can feed a fake sysfs tree.
#ifndef VV_THREADS_H
#define VV_THREADS_H

#include <algorithm>
#include <cstdio>
#include <string>
#include <thread>
#include <vector>

#if defined(__APPLE__)
#include <sys/sysctl.h>
#endif

namespace vv {

// Per-core cpuinfo_max_freq (kHz) under `<root>/devices/system/cpu/cpuN/cpufreq/`;
// stops at the first missing core. Empty when the tree is unreadable.
inline std::vector<long> read_core_max_freqs(const std::string& root) {
  std::vector<long> out;
  for (int i = 0; i < 1024; ++i) {
    const std::string p =
        root + "/devices/system/cpu/cpu" + std::to_string(i) + "/cpufreq/cpuinfo_max_freq";
    FILE* f = std::fopen(p.c_str(), "r");
    if (!f) break;
    long khz = 0;
    if (std::fscanf(f, "%ld", &khz) != 1) khz = 0;
    std::fclose(f);
    out.push_back(khz);
  }
  return out;
}

// Cores outside the slowest cluster (big + prime on big.LITTLE / DynamIQ).
// All cores equal (or one cluster) => all cores. Unknown freqs => 0.
inline int perf_cores_from_freqs(const std::vector<long>& freqs) {
  std::vector<long> known;
  for (long f : freqs)
    if (f > 0) known.push_back(f);
  if (known.empty()) return 0;
  const long slowest = *std::min_element(known.begin(), known.end());
  const long fastest = *std::max_element(known.begin(), known.end());
  if (slowest == fastest) return static_cast<int>(known.size());
  return static_cast<int>(std::count_if(known.begin(), known.end(),
                                        [&](long f) { return f > slowest; }));
}

inline int perf_cores(const std::string& sysfs_root = "/sys") {
#if defined(__APPLE__)
  int n = 0;
  size_t len = sizeof(n);
  if (sysctlbyname("hw.perflevel0.physicalcpu", &n, &len, nullptr, 0) == 0 && n > 0) return n;
#endif
  const int n_sysfs = perf_cores_from_freqs(read_core_max_freqs(sysfs_root));
  if (n_sysfs > 0) return n_sysfs;
  const unsigned hc = std::thread::hardware_concurrency();
  return hc > 1 ? static_cast<int>(hc / 2) : 1;
}

}  // namespace vv

#endif  // VV_THREADS_H
