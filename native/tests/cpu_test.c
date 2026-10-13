/* [LLM-03] Host test: big.LITTLE performance-core detection over fake sysfs
 * trees (Snapdragon 8 Gen 3, Snapdragon 7 Gen 3, Tensor G3, single cluster,
 * empty) and the CPU-feature guard that prevents SIGILL on CPUs lacking the
 * compiled-in ggml features. Usage: vv_cpu_test <scratch dir>. */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "vv_cpu.h"
#include "vv_llama.h"

static int failures = 0;
#define CHECK(cond)                                                   \
  do {                                                                \
    if (!(cond)) {                                                    \
      fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
      failures++;                                                     \
    }                                                                 \
  } while (0)

static void mkdirs(const char* path) {
  char tmp[1024];
  snprintf(tmp, sizeof tmp, "%s", path);
  for (char* p = tmp + 1; *p; p++) {
    if (*p == '/') {
      *p = 0;
      mkdir(tmp, 0755);
      *p = '/';
    }
  }
  mkdir(tmp, 0755);
}

/* Writes <root>/cpuI/cpufreq/cpuinfo_max_freq for each frequency (kHz). */
static void make_tree(const char* root, const unsigned* khz, int n) {
  char dir[1024], file[1100];
  for (int i = 0; i < n; i++) {
    snprintf(dir, sizeof dir, "%s/cpu%d/cpufreq", root, i);
    mkdirs(dir);
    snprintf(file, sizeof file, "%s/cpuinfo_max_freq", dir);
    FILE* f = fopen(file, "w");
    if (!f) {
      fprintf(stderr, "cannot write %s: %s\n", file, strerror(errno));
      exit(2);
    }
    fprintf(f, "%u\n", khz[i]);
    fclose(f);
  }
}

static int perf(const char* base, const char* name, const unsigned* khz, int n,
                uint8_t mask[VV_CPU_MAX]) {
  char root[1024];
  snprintf(root, sizeof root, "%s/%s", base, name);
  make_tree(root, khz, n);
  return vv_internal_perf_cores_sysfs(root, mask);
}

int main(int argc, char** argv) {
  const char* base = argc > 1 ? argv[1] : "cpu_test_sysfs";
  mkdirs(base);
  uint8_t m[VV_CPU_MAX];

  /* Snapdragon 8 Gen 3: 1x3.30 + 3x3.15 + 2x2.96 + 2x2.27 GHz -> 6 perf. */
  const unsigned sd8g3[] = {2265600, 2265600, 2956800, 2956800, 3148800, 3148800, 3148800, 3302400};
  CHECK(perf(base, "sd8g3", sd8g3, 8, m) == 6);
  CHECK(m[0] == 0 && m[1] == 0 && m[2] == 1 && m[7] == 1);

  /* Snapdragon 7 Gen 3: 4x1.8 + 3x2.4 + 1x2.63 -> 4 perf. */
  const unsigned sd7g3[] = {1804800, 1804800, 1804800, 1804800, 2400000, 2400000, 2400000, 2630400};
  CHECK(perf(base, "sd7g3", sd7g3, 8, m) == 4);
  CHECK(m[3] == 0 && m[4] == 1);

  /* Tensor G3: 4x1.70 + 4x2.37 + 1x2.91 -> 5 perf. */
  const unsigned g3[] = {1704000, 1704000, 1704000, 1704000, 2367000, 2367000, 2367000, 2367000, 2914000};
  CHECK(perf(base, "tensor_g3", g3, 9, m) == 5);

  /* Single cluster (all equal): every core is a performance core. */
  const unsigned one[] = {2000000, 2000000, 2000000, 2000000};
  CHECK(perf(base, "single", one, 4, m) == 4);

  /* No cpufreq data -> 0 (caller falls back to half the cores). */
  CHECK(vv_internal_perf_cores_sysfs("/nonexistent/sysfs", m) == 0);
  CHECK(vv_internal_perf_cores_sysfs(NULL, m) == 0);

  /* Exported wrapper always answers >= 1. */
  CHECK(vv_cpu_perf_cores() >= 1);

  /* HWCAP mapping (Linux arm64 uapi bits). */
  CHECK(vv_internal_features_from_hwcap(0, 0) == 0);
  CHECK(vv_internal_features_from_hwcap(1UL << 1, 0) == VV_CPU_FEATURE_NEON);
  CHECK(vv_internal_features_from_hwcap((1UL << 1) | (1UL << 20), 0) ==
        (VV_CPU_FEATURE_NEON | VV_CPU_FEATURE_DOTPROD));
  CHECK(vv_internal_features_from_hwcap(1UL << 1, 1UL << 13) ==
        (VV_CPU_FEATURE_NEON | VV_CPU_FEATURE_I8MM));
  CHECK((vv_internal_features_from_hwcap(1UL << 22, 0) & VV_CPU_FEATURE_SVE) != 0);

  /* Guard logic: a dotprod build on a plain-NEON CPU (Cortex-A53) must be
   * refused; a baseline build runs everywhere. */
  const int32_t neon = VV_CPU_FEATURE_NEON, dp = VV_CPU_FEATURE_DOTPROD, mm = VV_CPU_FEATURE_I8MM;
  CHECK(vv_internal_cpu_supported(neon, neon | dp) == 0);
  CHECK(vv_internal_cpu_supported(neon | dp, neon | dp | mm) == 0);
  CHECK(vv_internal_cpu_supported(neon | dp | mm, neon | dp) == 1);
  CHECK(vv_internal_cpu_supported(neon, neon) == 1);
  CHECK(vv_internal_cpu_supported(0, 0) == 1);

  /* Guard: this very host runs the library, so it must report supported
   * (build features are a subset of runtime features). */
  int32_t rt = -1, b = -1;
  CHECK(vv_cpu_features(&rt, &b) == VV_OK);
  CHECK(rt >= 0 && b >= 0);
  CHECK((b & ~rt) == 0);
  CHECK(vv_cpu_supported() == 1);
  CHECK(vv_cpu_features(NULL, NULL) == VV_OK);
  printf("cpu features runtime=0x%x build=0x%x perf_cores=%d\n", rt, b, vv_cpu_perf_cores());
  return failures ? 1 : 0;
}
