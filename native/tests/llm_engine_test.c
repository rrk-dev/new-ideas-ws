/* [LLM-04] Host test for the streaming engine (vv_llm_*): create/destroy,
 * invalid path, tokens, chat template, streaming callbacks, determinism,
 * VV_E_BUSY, cancel latency, destroy while running, grammar hook, and RSS
 * after unload. Model cases need SmolLM2-135M ($VV_TEST_MODELS_DIR);
 * otherwise SKIP (exit 77) after the model-free checks. */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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
  char text[65536];
  size_t len;
  int chunks;
  int done;
  int status;
  int n_gen;
  double first_text_at;
} Sink;

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static void on_text(void* user, char* text) {
  Sink* s = (Sink*)user;
  pthread_mutex_lock(&s->mu);
  size_t n = strlen(text);
  if (s->len + n < sizeof s->text) {
    memcpy(s->text + s->len, text, n);
    s->len += n;
    s->text[s->len] = 0;
  }
  if (s->chunks++ == 0) s->first_text_at = now_ms();
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  vv_free_string(text); /* receiver owns the text */
}

static void on_done(void* user, int32_t status, int32_t n_chunks, int32_t n_prompt, int32_t n_gen,
                    double pp, double tg) {
  (void)n_prompt, (void)pp, (void)tg;
  Sink* s = (Sink*)user;
  pthread_mutex_lock(&s->mu);
  s->done = 1;
  s->status = status;
  s->n_gen = n_gen;
  if (n_chunks != s->chunks) s->status = 999; /* chunk count must match */
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
}

static void sink_init(Sink* s) {
  memset(s, 0, sizeof *s);
  pthread_mutex_init(&s->mu, NULL);
  pthread_cond_init(&s->cv, NULL);
}

static void wait_done(Sink* s) {
  pthread_mutex_lock(&s->mu);
  while (!s->done) pthread_cond_wait(&s->cv, &s->mu);
  pthread_mutex_unlock(&s->mu);
}

static void wait_chunks(Sink* s, int n) {
  pthread_mutex_lock(&s->mu);
  while (s->chunks < n && !s->done) pthread_cond_wait(&s->cv, &s->mu);
  pthread_mutex_unlock(&s->mu);
}

static int generate(vv_llm* h, const char* prompt, vv_gen_params g, Sink* s) {
  sink_init(s);
  vv_llm_callbacks cb = {on_text, on_done, s};
  int rc = vv_llm_generate_async(h, prompt, &g, cb);
  if (rc == VV_OK) wait_done(s);
  return rc;
}

int main(void) {
  /* --- model-free ----------------------------------------------------- */
  vv_llm* h = NULL;
  vv_llm_backend_params bp = vv_llm_default_backend_params();
  CHECK(vv_llm_create(NULL, &bp, &h) == VV_E_INVALID_ARG);
  CHECK(vv_llm_create("/nonexistent/m.gguf", &bp, &h) == VV_E_MODEL_LOAD);
  CHECK(h == NULL);
  vv_llm_destroy(NULL); /* safe */
  vv_gen_params g0 = vv_llm_default_gen_params();
  CHECK(g0.struct_size == (int32_t)sizeof g0 && g0.repeat_penalty == 1.0f && g0.seed == 42);
  uint64_t cur = 0, peak = 0;
  CHECK(vv_proc_memory(&cur, &peak) == VV_OK && cur > 0 && peak >= cur);
  CHECK(vv_proc_memory(NULL, NULL) == VV_E_INVALID_ARG);

  const char* dir = getenv("VV_TEST_MODELS_DIR");
  char path[1024];
  snprintf(path, sizeof path, "%s/SmolLM2-135M-Instruct-Q8_0.gguf", dir ? dir : "");
  FILE* f = dir ? fopen(path, "rb") : NULL;
  if (!f) {
    printf("SKIP model cases: set VV_TEST_MODELS_DIR\n");
    return failures ? 1 : 77;
  }
  fclose(f);

  /* --- create / info / tokens / template ------------------------------- */
  uint64_t base = 0;
  vv_proc_memory(&base, NULL);
  bp.n_ctx = 1024;
  bp.n_batch = 256;
  CHECK(vv_llm_create(path, &bp, &h) == VV_OK && h);
  vv_llm_info info;
  memset(&info, 0, sizeof info);
  info.struct_size = (int32_t)sizeof info;
  CHECK(vv_llm_get_info(h, &info) == VV_OK);
  CHECK(info.n_ctx >= 1024 && info.model_bytes > 100u * 1024 * 1024);
  int32_t nt = 0;
  CHECK(vv_llm_count_tokens(h, "Hello world, this is a test.", &nt) == VV_OK && nt > 3 && nt < 20);
  vv_chat_msg msgs[2] = {{"system", "You are terse."}, {"user", "Write a long story about a dragon and a knight."}};
  char* prompt = NULL;
  CHECK(vv_llm_apply_chat_template(h, msgs, 2, &prompt) == VV_OK && prompt);
  CHECK(prompt && strstr(prompt, "dragon and a knight") != NULL);

  /* --- streaming + determinism (same seed, temp 0.8) ------------------ */
  Sink a, b;
  vv_gen_params g = vv_llm_default_gen_params();
  g.temperature = 0.8f;
  g.seed = 7;
  g.n_predict = 48;
  CHECK(generate(h, prompt, g, &a) == VV_OK);
  CHECK(a.status == VV_OK && a.n_gen > 0 && a.len > 0 && a.chunks >= 1);
  CHECK(generate(h, prompt, g, &b) == VV_OK);
  CHECK(b.status == VV_OK && strcmp(a.text, b.text) == 0); /* [LLM-04/AC2] */
  printf("gen: %d tokens in %d chunks\n", a.n_gen, a.chunks);

  /* --- busy + cancel latency ------------------------------------------ */
  Sink c;
  sink_init(&c);
  vv_gen_params lg = vv_llm_default_gen_params();
  lg.n_predict = 700; /* long */
  lg.token_batch = 1;
  vv_llm_callbacks cb = {on_text, on_done, &c};
  CHECK(vv_llm_generate_async(h, prompt, &lg, cb) == VV_OK);
  CHECK(vv_llm_generate_async(h, prompt, &lg, cb) == VV_E_BUSY);
  wait_chunks(&c, 3);
  double t0 = now_ms();
  vv_llm_cancel(h);
  wait_done(&c);
  double cancel_ms = now_ms() - t0;
  CHECK(c.status == VV_E_CANCELLED);
  CHECK(cancel_ms < 500.0); /* [LLM-04/AC1] */
  printf("cancel: %.1f ms after %d tokens\n", cancel_ms, c.n_gen);

  /* --- grammar hook ---------------------------------------------------- */
  Sink d;
  vv_gen_params gg = vv_llm_default_gen_params();
  gg.n_predict = 64;
  gg.grammar = "root ::= \"{\\\"ok\\\": \" (\"true\" | \"false\") \"}\"";
  CHECK(generate(h, prompt, gg, &d) == VV_OK);
  if (d.status != VV_OK) fprintf(stderr, "grammar status %d text [%s]\n", d.status, d.text);
  CHECK(d.status == VV_OK);
  CHECK(strcmp(d.text, "{\"ok\": true}") == 0 || strcmp(d.text, "{\"ok\": false}") == 0);
  gg.grammar = "root ::= (((";
  sink_init(&d);
  vv_llm_callbacks dcb = {on_text, on_done, &d};
  CHECK(vv_llm_generate_async(h, prompt, &gg, dcb) == VV_E_INVALID_ARG);

  /* prompt too long for n_ctx - n_predict -> done(VV_E_INVALID_ARG) */
  Sink e;
  vv_gen_params big = vv_llm_default_gen_params();
  big.n_predict = 1020;
  CHECK(generate(h, prompt, big, &e) == VV_OK && e.status == VV_E_INVALID_ARG);

  /* --- destroy while generating ----------------------------------------- */
  Sink w;
  sink_init(&w);
  vv_llm_callbacks wcb = {on_text, on_done, &w};
  CHECK(vv_llm_generate_async(h, prompt, &lg, wcb) == VV_OK);
  wait_chunks(&w, 1);
  vv_free_string(prompt);
  vv_llm_destroy(h); /* cancels + joins */
  CHECK(w.done && w.status == VV_E_CANCELLED);

  /* --- unload returns memory [LLM-04/AC3] -------------------------------- *
   * The first load of a process also initialises process-wide backend state
   * (Metal device, compiled pipelines) that is never freed. The baseline is
   * therefore taken after that first cycle: each further load + generate +
   * unload must return to it within 50 MiB, for GPU and CPU backends. */
  uint64_t warm = 0, after = 0;
  vv_proc_memory(&warm, NULL);
  long long worst = 0;
  for (int i = 0; i < 6; i++) {
    vv_llm_backend_params cp = bp;
    cp.use_gpu = i % 2; /* alternate CPU / GPU */
    vv_llm* m = NULL;
    CHECK(vv_llm_create(path, &cp, &m) == VV_OK);
    Sink r;
    vv_gen_params rg = vv_llm_default_gen_params();
    rg.n_predict = 16;
    CHECK(m && generate(m, "The quick brown fox", rg, &r) == VV_OK && r.status == VV_OK);
    uint64_t loaded = 0;
    vv_proc_memory(&loaded, NULL);
    vv_llm_destroy(m);
    vv_proc_memory(&after, NULL);
    long long d = (long long)after - (long long)warm;
    if (d > worst) worst = d;
    printf("memory cycle %d (%s): loaded %llu MiB -> unloaded %llu MiB\n", i, cp.use_gpu ? "gpu" : "cpu",
           (unsigned long long)(loaded >> 20), (unsigned long long)(after >> 20));
  }
  printf("memory: first-load base %llu MiB, warm baseline %llu MiB, worst delta %lld MiB\n",
         (unsigned long long)(base >> 20), (unsigned long long)(warm >> 20), worst >> 20);
  CHECK(worst < 50LL * 1024 * 1024); /* [LLM-04/AC3] */
  return failures ? 1 : 0;
}
