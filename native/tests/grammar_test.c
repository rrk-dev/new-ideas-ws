/* [LLM-05] Host test: vv_json_schema_to_gbnf (vv_jsg, no llama-common) and
 * the lazy grammar sampler. Model-free: conversion, error paths. With
 * SmolLM2 ($VV_TEST_MODELS_DIR): schema grammar yields JSON, and LAZY mode
 * produces exactly the FULL-mask output under greedy decoding (same
 * constraint, cheaper). Exit 77 = SKIP model cases. */
#include <pthread.h>
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

typedef struct {
  pthread_mutex_t mu;
  pthread_cond_t cv;
  int done, status;
  size_t len;
  char text[8192];
} Sink;

static void on_text(void* u, char* t) {
  Sink* s = (Sink*)u;
  size_t n = strlen(t);
  pthread_mutex_lock(&s->mu);
  if (s->len + n < sizeof s->text) {
    memcpy(s->text + s->len, t, n);
    s->len += n;
    s->text[s->len] = 0;
  }
  pthread_mutex_unlock(&s->mu);
  vv_free_string(t);
}

static void on_done(void* u, int32_t st, int32_t c, int32_t np, int32_t ng, double a, double b) {
  (void)c, (void)np, (void)ng, (void)a, (void)b;
  Sink* s = (Sink*)u;
  pthread_mutex_lock(&s->mu);
  s->done = 1;
  s->status = st;
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
}

static int run(vv_llm* h, const char* prompt, const char* grammar, int mode, Sink* s) {
  memset(s, 0, sizeof *s);
  pthread_mutex_init(&s->mu, NULL);
  pthread_cond_init(&s->cv, NULL);
  vv_gen_params g = vv_llm_default_gen_params();
  g.temperature = 0;
  g.n_predict = 160;
  g.grammar = grammar;
  g.grammar_mode = mode;
  vv_llm_callbacks cb = {on_text, on_done, s};
  int rc = vv_llm_generate_async(h, prompt, &g, cb);
  if (rc != VV_OK) return rc;
  pthread_mutex_lock(&s->mu);
  while (!s->done) pthread_cond_wait(&s->cv, &s->mu);
  pthread_mutex_unlock(&s->mu);
  return s->status;
}

static const char* kSchema =
    "{\"type\":\"object\",\"required\":[\"title\",\"items\"],\"additionalProperties\":false,"
    "\"properties\":{\"title\":{\"type\":\"string\",\"maxLength\":60},"
    "\"items\":{\"type\":\"array\",\"maxItems\":3,\"items\":{\"type\":\"object\","
    "\"required\":[\"text\",\"t\"],\"additionalProperties\":false,\"properties\":{"
    "\"text\":{\"type\":\"string\",\"maxLength\":80},"
    "\"t\":{\"type\":\"string\",\"pattern\":\"^[0-9]{2}:[0-5][0-9]:[0-5][0-9]$\"}}}},"
    "\"kind\":{\"enum\":[\"meeting\",\"call\"]}}}";

int main(void) {
  char* g = NULL;
  CHECK(vv_json_schema_to_gbnf(kSchema, &g) == VV_OK && g);
  CHECK(g && strstr(g, "root ::=") != NULL);
  CHECK(g && strstr(g, "\\\"meeting\\\"") != NULL); /* enum literal \"meeting\" */
  if (g) printf("gbnf: %zu bytes\n%s\n", strlen(g), getenv("VV_PRINT_GBNF") ? g : "");
  char* bad = (char*)1;
  CHECK(vv_json_schema_to_gbnf("{not json", &bad) == VV_E_INVALID_ARG && bad == NULL);
  CHECK(vv_json_schema_to_gbnf(NULL, &bad) == VV_E_INVALID_ARG);
  CHECK(vv_json_schema_to_gbnf("{\"type\":\"object\"}", NULL) == VV_E_INVALID_ARG);

  const char* dir = getenv("VV_TEST_MODELS_DIR");
  char path[1024];
  snprintf(path, sizeof path, "%s/SmolLM2-135M-Instruct-Q8_0.gguf", dir ? dir : "");
  FILE* f = dir ? fopen(path, "rb") : NULL;
  if (!f) {
    vv_free_string(g);
    printf("SKIP model cases: set VV_TEST_MODELS_DIR\n");
    return failures ? 1 : 77;
  }
  fclose(f);
  vv_llm_backend_params bp = vv_llm_default_backend_params();
  bp.n_ctx = 1024;
  vv_llm* h = NULL;
  CHECK(vv_llm_create(path, &bp, &h) == VV_OK);
  vv_chat_msg m[1] = {{"user",
                       "[00:00:05] A: We ship on Friday.\n[00:01:10] B: Ana writes the notes.\n"
                       "Extract title and items as JSON."}};
  char* prompt = NULL;
  CHECK(vv_llm_apply_chat_template(h, m, 1, &prompt) == VV_OK);
  Sink full, lazy;
  CHECK(run(h, prompt, g, VV_LLM_GRAMMAR_FULL, &full) == VV_OK);
  CHECK(run(h, prompt, g, VV_LLM_GRAMMAR_LAZY, &lazy) == VV_OK);
  CHECK(full.len > 0 && full.text[0] == '{');
  CHECK(strcmp(full.text, lazy.text) == 0); /* lazy == full under greedy */
  printf("full: %zu bytes, lazy identical: %s\n", full.len, strcmp(full.text, lazy.text) == 0 ? "yes" : "no");
  vv_free_string(prompt);
  vv_free_string(g);
  vv_llm_destroy(h);
  return failures ? 1 : 0;
}
