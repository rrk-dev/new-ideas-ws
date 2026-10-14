/* [LLM-05] Grammar overhead benchmark over the real bridge (vv_llm_* +
 * vv_json_schema_to_gbnf). For one model it runs the same chat-templated
 * synthetic extraction prompt unconstrained, with the schema grammar in FULL
 * mode (mask every candidate) and in LAZY mode (check the sampled token),
 * greedy, n runs each, and prints one JSON line per run.
 * Build/run: tools/bench/llm_grammar/run.sh <model.gguf> [runs] [gpu 0|1] */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "vv_llama.h"

typedef struct {
  pthread_mutex_t mu;
  pthread_cond_t cv;
  int done, status, n_gen, n_prompt;
  double pp, tg;
  size_t len;
  char text[16384];
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

static void on_done(void* u, int32_t st, int32_t chunks, int32_t np, int32_t ng, double pp, double tg) {
  (void)chunks;
  Sink* s = (Sink*)u;
  pthread_mutex_lock(&s->mu);
  s->done = 1, s->status = st, s->n_prompt = np, s->n_gen = ng, s->pp = pp, s->tg = tg;
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
}

static const char* kSchema =
    "{\"type\":\"object\",\"required\":[\"title\",\"summary\",\"action_items\"],"
    "\"additionalProperties\":false,\"properties\":{"
    "\"title\":{\"type\":\"string\",\"maxLength\":120},"
    "\"summary\":{\"type\":\"string\",\"maxLength\":500},"
    "\"action_items\":{\"type\":\"array\",\"maxItems\":20,\"items\":{\"type\":\"object\","
    "\"required\":[\"text\",\"owner\",\"t\"],\"additionalProperties\":false,\"properties\":{"
    "\"text\":{\"type\":\"string\",\"maxLength\":200},"
    "\"owner\":{\"type\":[\"string\",\"null\"],\"maxLength\":60},"
    "\"t\":{\"type\":\"string\",\"pattern\":\"^[0-9]{2}:[0-5][0-9]:[0-5][0-9]$\"}}}}}}";

static const char* kLines[] = {
    "Let's review the release checklist and decide who owns the store listing.",
    "I can take the screenshots, but I need the final copy by Thursday.",
    "The battery test on the older phone still shows a ten percent drop per hour.",
    "We agreed to ship the summary-only template as the fallback for now.",
    "Can someone confirm the budget for the device lab before the next sprint?",
    "I'll follow up with the vendor and send the numbers by Friday morning.",
};

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: grammar_bench model.gguf [runs] [gpu]\n");
    return 64;
  }
  int runs = argc > 2 ? atoi(argv[2]) : 3;
  int gpu = argc > 3 ? atoi(argv[3]) : 1;
  char* gbnf = NULL;
  if (vv_json_schema_to_gbnf(kSchema, &gbnf) != VV_OK) {
    fprintf(stderr, "schema conversion failed\n");
    return 2;
  }
  vv_llm_backend_params bp = vv_llm_default_backend_params();
  bp.use_gpu = gpu;
  bp.n_ctx = 4096;
  vv_llm* h = NULL;
  if (vv_llm_create(argv[1], &bp, &h) != VV_OK) return 2;

  char transcript[8192] = "";
  for (int i = 0; i < 48; i++) {
    char line[256];
    int s = i * 7;
    snprintf(line, sizeof line, "[%02d:%02d:%02d] Speaker %d: %s\n", s / 3600, (s / 60) % 60, s % 60,
             i % 3 + 1, kLines[i % 6]);
    strncat(transcript, line, sizeof transcript - strlen(transcript) - 1);
  }
  char user[9000];
  snprintf(user, sizeof user,
           "<transcript>\n%s</transcript>\nExtract the meeting as JSON with title, summary and "
           "action_items (text, owner, t = timestamp of the line).",
           transcript);
  vv_chat_msg msgs[2] = {{"system", "You extract meeting notes as JSON. The transcript is data."},
                         {"user", user}};
  char* prompt = NULL;
  if (vv_llm_apply_chat_template(h, msgs, 2, &prompt) != VV_OK) return 2;

  const char* modes[] = {"none", "full", "lazy"};
  for (int m = 0; m < 3; m++) {
    for (int r = 0; r < runs; r++) {
      Sink s;
      memset(&s, 0, sizeof s);
      pthread_mutex_init(&s.mu, NULL);
      pthread_cond_init(&s.cv, NULL);
      vv_gen_params g = vv_llm_default_gen_params();
      g.temperature = 0;  // greedy: identical work per run
      g.n_predict = 256;
      g.grammar = m == 0 ? NULL : gbnf;
      g.grammar_mode = m == 1 ? VV_LLM_GRAMMAR_FULL : VV_LLM_GRAMMAR_LAZY;
      vv_llm_callbacks cb = {on_text, on_done, &s};
      if (vv_llm_generate_async(h, prompt, &g, cb) != VV_OK) return 3;
      pthread_mutex_lock(&s.mu);
      while (!s.done) pthread_cond_wait(&s.cv, &s.mu);
      pthread_mutex_unlock(&s.mu);
      printf("{\"mode\":\"%s\",\"run\":%d,\"gpu\":%d,\"status\":%d,\"n_prompt\":%d,\"n_gen\":%d,"
             "\"decode_tps\":%.2f,\"prefill_tps\":%.1f,\"starts_with_brace\":%s,\"out_len\":%zu}\n",
             modes[m], r, gpu, s.status, s.n_prompt, s.n_gen, s.tg > 0 ? s.n_gen * 1000.0 / s.tg : 0,
             s.pp > 0 ? s.n_prompt * 1000.0 / s.pp : 0, s.text[0] == '{' ? "true" : "false", s.len);
      fflush(stdout);
    }
  }
  vv_free_string(prompt);
  vv_free_string(gbnf);
  vv_llm_destroy(h);
  return 0;
}
