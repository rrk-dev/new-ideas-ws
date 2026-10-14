/* Internal CPU topology helpers (LLM-03). See vv_cpu.h. */
#include "vv_cpu.h"

#include <stdio.h>
#include <string.h>

#if defined(__APPLE__)
#include <sys/sysctl.h>
#elif defined(__linux__) && defined(__aarch64__)
#include <sys/auxv.h>
#endif

/* Linux arm64 uapi bits (asm/hwcap.h); defined here so older NDK sysroots and
 * host builds compile the mapping. */
#define VV_HWCAP_ASIMD (1UL << 1)
#define VV_HWCAP_ASIMDDP (1UL << 20)
#define VV_HWCAP_SVE (1UL << 22)
#define VV_HWCAP2_I8MM (1UL << 13)

int32_t vv_internal_features_from_hwcap(unsigned long hwcap, unsigned long hwcap2) {
  int32_t f = 0;
  if (hwcap & VV_HWCAP_ASIMD) f |= VV_CPU_FEAT_NEON;
  if (hwcap & VV_HWCAP_ASIMDDP) f |= VV_CPU_FEAT_DOTPROD;
  if (hwcap & VV_HWCAP_SVE) f |= VV_CPU_FEAT_SVE;
  if (hwcap2 & VV_HWCAP2_I8MM) f |= VV_CPU_FEAT_I8MM;
  return f;
}

int32_t vv_internal_cpu_supported(int32_t runtime, int32_t build) {
  return (build & ~runtime) == 0 ? 1 : 0;
}

#if defined(__APPLE__)
static int sysctl_flag(const char* name) {
  int v = 0;
  size_t len = sizeof v;
  return sysctlbyname(name, &v, &len, NULL, 0) == 0 && v != 0;
}
#endif

int32_t vv_internal_runtime_features(void) {
#if defined(__APPLE__) && defined(__aarch64__)
  int32_t f = VV_CPU_FEAT_NEON; /* every Apple arm64 CPU */
  if (sysctl_flag("hw.optional.arm.FEAT_DotProd")) f |= VV_CPU_FEAT_DOTPROD;
  if (sysctl_flag("hw.optional.arm.FEAT_I8MM")) f |= VV_CPU_FEAT_I8MM;
  return f;
#elif defined(__linux__) && defined(__aarch64__)
  return vv_internal_features_from_hwcap(getauxval(AT_HWCAP), getauxval(AT_HWCAP2));
#else
  return 0;
#endif
}

int32_t vv_internal_perf_cores_sysfs(const char* root, uint8_t mask[VV_CPU_MAX]) {
  unsigned long long freq[VV_CPU_MAX];
  int present[VV_CPU_MAX];
  unsigned long long lo = 0;
  int n = 0;
  memset(mask, 0, VV_CPU_MAX);
  if (!root) return 0;
  for (int i = 0; i < VV_CPU_MAX; i++) {
    char path[512];
    snprintf(path, sizeof path, "%s/cpu%d/cpufreq/cpuinfo_max_freq", root, i);
    FILE* f = fopen(path, "r");
    present[i] = 0;
    freq[i] = 0;
    if (!f) continue;
    if (fscanf(f, "%llu", &freq[i]) == 1 && freq[i] > 0) {
      present[i] = 1;
      if (n == 0 || freq[i] < lo) lo = freq[i];
      n++;
    }
    fclose(f);
  }
  if (n == 0) return 0;
  int perf = 0;
  int all_equal = 1;
  for (int i = 0; i < VV_CPU_MAX; i++)
    if (present[i] && freq[i] != lo) all_equal = 0;
  for (int i = 0; i < VV_CPU_MAX; i++) {
    if (present[i] && (all_equal || freq[i] > lo)) {
      mask[i] = 1;
      perf++;
    }
  }
  return perf;
}
