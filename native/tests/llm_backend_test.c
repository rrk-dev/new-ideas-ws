/* [LLM-02] Host test for the llama.cpp backend bridge (vv_llama.h):
 * argument validation, GPU device discovery, GPU (Metal on macOS) and
 * CPU-only runs, q8_0 -> f16 KV fallback, determinism.
 * Model-dependent cases need SmolLM2-135M from tools/ci/fetch_test_models.sh
 * ($VV_TEST_MODELS_DIR); without it they are skipped (exit 77 = ctest SKIP)
 * after the model-free checks pass. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "vv_llama.h"

static int failures = 0;
#define CHECK(cond)                                                   \
  do {                                                                \
    if (!(cond)) {                                                    \
      fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
      failures++;                                                     \
    }                                                                 \
  } while (0)

static vv_llm_bench_result fresh(void) {
  vv_llm_bench_result r;
  memset(&r, 0, sizeof r);
  r.struct_size = (int32_t)sizeof r;
  return r;
}

static vv_llm_backend_params small(int gpu) {
  vv_llm_backend_params p = vv_llm_default_backend_params();
  p.use_gpu = gpu;
  p.n_ctx = 512;
  p.n_batch = 128;
  return p;
}

int main(void) {
  /* --- model-free checks -------------------------------------------- */
  vv_llm_backend_params d = vv_llm_default_backend_params();
  CHECK(d.struct_size == (int32_t)sizeof d);
  CHECK(d.use_gpu == 1 && d.gpu_device == -1 && d.kv_quant == 1);
  CHECK(d.flash_attn == VV_LLM_FLASH_ATTN_AUTO && d.use_mmap == 1);
  CHECK(vv_cpu_perf_cores() >= 1);

  int32_t ngpu = vv_llm_gpu_device_count();
  CHECK(ngpu >= 0);
  char name[64], desc[128];
  for (int32_t i = 0; i < ngpu; i++) {
    CHECK(vv_llm_gpu_device_info(i, name, sizeof name, desc, sizeof desc) == VV_OK);
    CHECK(strlen(name) > 0);
    printf("gpu[%d] %s / %s\n", i, name, desc);
  }
  CHECK(vv_llm_gpu_device_info(ngpu, name, sizeof name, desc, sizeof desc) == VV_E_INVALID_ARG);
  CHECK(vv_llm_gpu_device_info(-1, name, sizeof name, desc, sizeof desc) == VV_E_INVALID_ARG);
#if defined(__APPLE__)
  CHECK(ngpu >= 1); /* Metal device on Apple silicon hosts */
#endif

  vv_llm_bench_result r = fresh();
  vv_llm_backend_params p = small(1);
  CHECK(vv_llm_bench(NULL, &p, 8, 8, &r) == VV_E_INVALID_ARG);
  CHECK(vv_llm_bench("x.gguf", NULL, 8, 8, &r) == VV_E_INVALID_ARG);
  CHECK(vv_llm_bench("x.gguf", &p, 8, 8, NULL) == VV_E_INVALID_ARG);
  CHECK(vv_llm_bench("x.gguf", &p, 500, 100, &r) == VV_E_INVALID_ARG); /* > n_ctx */
  vv_llm_backend_params bad = p;
  bad.struct_size = 4;
  CHECK(vv_llm_bench("x.gguf", &bad, 8, 8, &r) == VV_E_INVALID_ARG);
  bad = p;
  bad.gpu_device = ngpu; /* out of range */
  CHECK(vv_llm_bench("x.gguf", &bad, 8, 8, &r) == VV_E_INVALID_ARG);
  CHECK(vv_llm_bench("/nonexistent/model.gguf", &p, 8, 8, &r) == VV_E_MODEL_LOAD);

  /* --- model checks -------------------------------------------------- */
  const char* dir = getenv("VV_TEST_MODELS_DIR");
  char path[1024];
  snprintf(path, sizeof path, "%s/SmolLM2-135M-Instruct-Q8_0.gguf", dir ? dir : "");
  FILE* f = dir ? fopen(path, "rb") : NULL;
  if (!f) {
    printf("SKIP model cases: set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)\n");
    return failures ? 1 : 77;
  }
  fclose(f);

  /* GPU requested: full offload on the GPU device when one exists. */
  r = fresh();
  p = small(1);
  CHECK(vv_llm_bench(path, &p, 64, 32, &r) == VV_OK);
  CHECK(r.used_gpu == (ngpu > 0));
  CHECK(r.n_gen == 32 && r.n_prompt == 64);
  CHECK(r.decode_tps > 0 && r.prefill_tps > 0);
  CHECK(r.model_bytes > 100u * 1024 * 1024);
  CHECK(r.peak_mem_bytes > 0);
  printf("gpu: used_gpu=%d kvq=%d fb=%d pp=%.0f tg=%.0f load=%.0fms peak=%lluMiB\n", r.used_gpu,
         r.used_kv_quant, r.fallbacks, r.prefill_tps, r.decode_tps, r.load_ms,
         (unsigned long long)(r.peak_mem_bytes >> 20));

  /* CPU only (iOS background path): no GPU attached, no fallback needed. */
  vv_llm_bench_result c1 = fresh(), c2 = fresh();
  p = small(0);
  p.n_threads = 2;
  CHECK(vv_llm_bench(path, &p, 64, 32, &c1) == VV_OK);
  CHECK(vv_llm_bench(path, &p, 64, 32, &c2) == VV_OK);
  CHECK(c1.used_gpu == 0 && c1.fallbacks == 0 && c1.n_threads == 2);
  CHECK(c1.output_hash == c2.output_hash); /* greedy => deterministic */
  printf("cpu: kvq=%d pp=%.0f tg=%.0f hash=%016llx\n", c1.used_kv_quant, c1.prefill_tps,
         c1.decode_tps, (unsigned long long)c1.output_hash);

  /* q8_0 V cache without flash attention cannot initialise -> f16 KV. */
  vv_llm_bench_result k = fresh();
  p = small(0);
  p.flash_attn = VV_LLM_FLASH_ATTN_OFF;
  p.kv_quant = 1;
  CHECK(vv_llm_bench(path, &p, 32, 8, &k) == VV_OK);
  CHECK(k.used_kv_quant == 0);
  CHECK((k.fallbacks & VV_LLM_FALLBACK_KV_TO_F16) != 0);

  return failures ? 1 : 0;
}
