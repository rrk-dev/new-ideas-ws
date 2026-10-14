/*
 * Internal (not exported) CPU topology + feature helpers for the bridge
 * (LLM-03). Pure functions over a sysfs root so host tests can feed fake
 * big.LITTLE layouts. The exported wrappers live in vv_llama.h.
 */
#ifndef VV_CPU_H
#define VV_CPU_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VV_CPU_MAX 64

/* Same bits as VV_CPU_FEATURE_* in vv_llama.h. */
#define VV_CPU_FEAT_NEON 1
#define VV_CPU_FEAT_DOTPROD 2
#define VV_CPU_FEAT_I8MM 4
#define VV_CPU_FEAT_SVE 8

/* Features the running CPU reports (never executes optional instructions). */
int32_t vv_internal_runtime_features(void);

/* Maps Linux AT_HWCAP / AT_HWCAP2 (aarch64) to VV_CPU_FEAT_* bits. Pure, so
 * host tests can check the bit mapping. */
int32_t vv_internal_features_from_hwcap(unsigned long hwcap, unsigned long hwcap2);

/* 1 when every `build` feature bit is present in `runtime`. */
int32_t vv_internal_cpu_supported(int32_t runtime, int32_t build);

/* Reads <root>/cpuN/cpufreq/cpuinfo_max_freq for N = 0.. and marks the
 * performance cores: every core faster than the slowest cluster (if all
 * cores share one max frequency, all are performance cores). Writes
 * mask[i] = 1/0 for i < VV_CPU_MAX and returns the count, or 0 when nothing
 * readable was found (caller falls back). */
int32_t vv_internal_perf_cores_sysfs(const char* root, uint8_t mask[VV_CPU_MAX]);

#ifdef __cplusplus
}
#endif

#endif /* VV_CPU_H */
