// VaultVoice LLM streaming engine (LLM-04): vv_llm_create / count_tokens /
// apply_chat_template / generate_async / cancel / destroy.
//
// Threading (vv-ffi-bridge): one std::thread worker per generation, one
// active generation per handle (VV_E_BUSY), cancellation through an atomic
// flag checked per token, per prefill slice and inside llama_decode via the
// context abort callback (CPU backend). Callbacks run on the worker thread;
// text is malloc'd and owned by the receiver (vv_free_string).
//
// llama.cpp v0.6.0 API: llama_sampler_sample() samples AND accepts — the
// chain (incl. the grammar) is never accepted a second time.
#include <atomic>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <thread>
#include <vector>

#include "vv_llama.h"
#include "vv_llama_internal.h"

using namespace vv_internal;

struct vv_llm {
  Loaded L;
  int32_t n_ctx = 0;
  int32_t n_batch = 512;
  std::atomic<bool> busy{false};
  std::atomic<bool> cancel{false};
  std::mutex mu;  // guards worker (start/join)
  std::thread worker;
};

namespace {

bool abort_cb(void* data) { return static_cast<vv_llm*>(data)->cancel.load(); }

char* dup_cstr(const std::string& s) {
  char* p = static_cast<char*>(malloc(s.size() + 1));
  if (!p) return nullptr;
  memcpy(p, s.data(), s.size());
  p[s.size()] = 0;
  return p;
}

// Length of the longest prefix of `s` that ends on a UTF-8 code point
// boundary (llama.cpp pieces can split multi-byte characters).
size_t utf8_complete_prefix(const std::string& s) {
  size_t n = s.size();
  size_t i = n;
  int back = 0;
  while (i > 0 && back < 4) {
    unsigned char c = (unsigned char)s[i - 1];
    if ((c & 0xC0) != 0x80) {  // lead byte or ASCII
      size_t need = c < 0x80 ? 1 : (c >> 5) == 0x6 ? 2 : (c >> 4) == 0xE ? 3 : (c >> 3) == 0x1E ? 4 : 1;
      return (n - (i - 1)) >= need ? n : i - 1;
    }
    i--;
    back++;
  }
  return n;
}

std::vector<llama_token> tokenize(const llama_vocab* vocab, const char* text, size_t len) {
  int n = -llama_tokenize(vocab, text, (int32_t)len, nullptr, 0, true, true);
  if (n <= 0) return {};
  std::vector<llama_token> t(n);
  if (llama_tokenize(vocab, text, (int32_t)len, t.data(), n, true, true) < 0) return {};
  return t;
}

// Builds the sampling chain. With a grammar and grammar_mode LAZY the grammar
// sampler is returned separately in *grammar_out (checked against the chosen
// token only, see sample_lazy); with FULL it is the first chain element and
// masks all candidates every step.
llama_sampler* build_chain(const llama_vocab* vocab, const vv_gen_params& g, bool* grammar_ok,
                           llama_sampler** grammar_out) {
  *grammar_ok = true;
  *grammar_out = nullptr;
  llama_sampler* chain = llama_sampler_chain_init(llama_sampler_chain_default_params());
  if (g.grammar && g.grammar[0]) {
    llama_sampler* gr = llama_sampler_init_grammar(vocab, g.grammar, "root");
    if (!gr) {
      *grammar_ok = false;
      llama_sampler_free(chain);
      return nullptr;
    }
    if (g.grammar_mode == VV_LLM_GRAMMAR_FULL) {
      llama_sampler_chain_add(chain, gr);
    } else {
      *grammar_out = gr;
    }
  }
  if (g.temperature <= 0.0f) {
    if (g.repeat_penalty != 1.0f && g.repeat_last_n != 0)
      llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), g.repeat_last_n,
                                                                  g.repeat_penalty, 0.0f, 0.0f));
    llama_sampler_chain_add(chain, llama_sampler_init_greedy());
    return chain;
  }
  if (g.top_k > 0) llama_sampler_chain_add(chain, llama_sampler_init_top_k(g.top_k));
  if (g.repeat_penalty != 1.0f && g.repeat_last_n != 0)
    llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), g.repeat_last_n,
                                                                g.repeat_penalty, 0.0f, 0.0f));
  if (g.top_p < 1.0f) llama_sampler_chain_add(chain, llama_sampler_init_top_p(g.top_p, 1));
  if (g.min_p > 0.0f) llama_sampler_chain_add(chain, llama_sampler_init_min_p(g.min_p, 1));
  llama_sampler_chain_add(chain, llama_sampler_init_temp(g.temperature));
  llama_sampler_chain_add(chain, llama_sampler_init_dist(g.seed));
  return chain;
}

struct Job {
  vv_llm* h;
  std::string prompt;
  vv_gen_params g;
  llama_sampler* chain;
  llama_sampler* grammar;  // LAZY mode only, else nullptr
  vv_llm_callbacks cb;
  int32_t chunks = 0;
  std::vector<llama_token_data> cur;
};

void fill_candidates(std::vector<llama_token_data>& cur, const float* logits, int n_vocab) {
  cur.resize(n_vocab);
  for (llama_token t = 0; t < n_vocab; t++) cur[t] = {t, logits[t], 0.0f};
}

// Grammar-checked sampling, the strategy of llama.cpp common/sampling.cpp
// (grammar_first = false): sample with the plain chain, then ask the grammar
// about that ONE token; only if it is rejected, mask the full vocabulary with
// the grammar and resample. Most steps cost one grammar check instead of a
// pass over 128k candidates. Each sampler is accepted exactly once.
llama_token sample_lazy(Job& j, llama_context* ctx, int n_vocab) {
  const float* logits = llama_get_logits_ith(ctx, -1);
  fill_candidates(j.cur, logits, n_vocab);
  llama_token_data_array arr = {j.cur.data(), j.cur.size(), -1, false};
  llama_sampler_apply(j.chain, &arr);
  llama_token id = arr.data[arr.selected].id;

  llama_token_data single = {id, 1.0f, 0.0f};
  llama_token_data_array one = {&single, 1, -1, false};
  llama_sampler_apply(j.grammar, &one);
  if (!std::isfinite(one.data[0].logit)) {  // rejected: full mask + resample
    fill_candidates(j.cur, logits, n_vocab);
    arr = {j.cur.data(), j.cur.size(), -1, false};
    llama_sampler_apply(j.grammar, &arr);
    llama_sampler_apply(j.chain, &arr);
    id = arr.data[arr.selected].id;
  }
  llama_sampler_accept(j.grammar, id);
  llama_sampler_accept(j.chain, id);
  return id;
}

void emit(Job& j, std::string& pending, bool flush) {
  size_t n = flush ? pending.size() : utf8_complete_prefix(pending);
  if (n == 0) return;
  if (char* s = dup_cstr(pending.substr(0, n))) {
    if (j.cb.on_text) {
      j.cb.on_text(j.cb.user, s);
      j.chunks++;
    } else {
      free(s);
    }
  }
  pending.erase(0, n);
}

int32_t run(Job& j, int32_t* n_prompt, int32_t* n_gen, double* prefill_ms, double* decode_ms) {
  vv_llm* h = j.h;
  llama_context* ctx = h->L.ctx;
  const llama_vocab* vocab = llama_model_get_vocab(h->L.model);
  llama_memory_clear(llama_get_memory(ctx), true);

  std::vector<llama_token> prompt = tokenize(vocab, j.prompt.data(), j.prompt.size());
  *n_prompt = (int32_t)prompt.size();
  if (prompt.empty() || (int64_t)prompt.size() + j.g.n_predict > h->n_ctx) return VV_E_INVALID_ARG;

  auto t0 = clk::now();
  for (size_t i = 0; i < prompt.size(); i += (size_t)h->n_batch) {
    if (h->cancel.load()) return VV_E_CANCELLED;
    int n = (int)std::min<size_t>((size_t)h->n_batch, prompt.size() - i);
    int rc = llama_decode(ctx, llama_batch_get_one(prompt.data() + i, n));
    if (rc == 2 || h->cancel.load()) return VV_E_CANCELLED;  // aborted
    if (rc != 0) return VV_E_BACKEND;
  }
  *prefill_ms = ms_since(t0);

  std::string pending;
  auto last_emit = clk::now();
  int since_emit = 0;
  t0 = clk::now();
  int32_t status = VV_OK;
  for (int32_t i = 0; i < j.g.n_predict; i++) {
    if (h->cancel.load()) {
      status = VV_E_CANCELLED;
      break;
    }
    llama_token tok = j.grammar ? sample_lazy(j, ctx, llama_vocab_n_tokens(vocab))
                                : llama_sampler_sample(j.chain, ctx, -1);  // samples + accepts
    if (llama_vocab_is_eog(vocab, tok)) break;
    char buf[256];
    int n = llama_token_to_piece(vocab, tok, buf, sizeof buf, 0, false);
    if (n > 0) {
      pending.append(buf, n);
    } else if (n < 0) {  // piece longer than buf: -n bytes needed
      std::string big((size_t)-n, '\0');
      int m = llama_token_to_piece(vocab, tok, big.data(), -n, 0, false);
      if (m > 0) pending.append(big.data(), m);
    }
    (*n_gen)++;
    if (++since_emit >= j.g.token_batch ||
        std::chrono::duration<double, std::milli>(clk::now() - last_emit).count() >= 50.0) {
      emit(j, pending, false);
      since_emit = 0;
      last_emit = clk::now();
    }
    int rc = llama_decode(ctx, llama_batch_get_one(&tok, 1));
    if (rc == 2 || h->cancel.load()) {
      status = VV_E_CANCELLED;
      break;
    }
    if (rc != 0) {
      status = VV_E_BACKEND;
      break;
    }
  }
  *decode_ms = ms_since(t0);
  emit(j, pending, true);
  return status;
}

void worker_main(Job j) {
  int32_t n_prompt = 0, n_gen = 0;
  double prefill_ms = 0, decode_ms = 0;
  int32_t status;
  try {
    status = run(j, &n_prompt, &n_gen, &prefill_ms, &decode_ms);
  } catch (const std::bad_alloc&) {
    status = VV_E_OOM;
  } catch (...) {
    status = VV_E_INTERNAL;
  }
  llama_sampler_free(j.chain);
  if (j.grammar) llama_sampler_free(j.grammar);
  vv_llm_done_cb done = j.cb.on_done;
  void* user = j.cb.user;
  j.h->busy.store(false);  // before on_done: the receiver may start the next job
  if (done) done(user, status, j.chunks, n_prompt, n_gen, prefill_ms, decode_ms);
}

}  // namespace

extern "C" {

void vv_free_string(char* s) { free(s); }

vv_gen_params vv_llm_default_gen_params(void) {
  vv_gen_params g;
  memset(&g, 0, sizeof g);
  g.struct_size = (int32_t)sizeof g;
  // Structured-extraction preset (vv-llm-inference): grammar + temp 0.2,
  // min_p 0.05, top_k 40, no repeat penalty (breaks JSON), fixed seed.
  g.n_predict = 1024;
  g.seed = 42;
  g.temperature = 0.2f;
  g.top_k = 40;
  g.top_p = 1.0f;
  g.min_p = 0.05f;
  g.repeat_penalty = 1.0f;
  g.repeat_last_n = 64;
  g.grammar = nullptr;
  g.token_batch = 4;
  return g;
}

int32_t vv_llm_create(const char* model_path, const vv_llm_backend_params* params, vv_llm** out) {
  if (!model_path || !params || !out || params->struct_size != (int32_t)sizeof(*params) ||
      params->n_ctx < 16 || params->n_batch < 1) {
    return VV_E_INVALID_ARG;
  }
  *out = nullptr;
  try {
    auto* h = new vv_llm();
    int32_t rc = open_model(model_path, *params, h->L);
    if (rc != VV_OK) {
      delete h;
      return rc;
    }
    h->n_ctx = (int32_t)llama_n_ctx(h->L.ctx);
    h->n_batch = params->n_batch;
    llama_set_abort_callback(h->L.ctx, abort_cb, h);
    *out = h;
    return VV_OK;
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_llm_get_info(vv_llm* h, vv_llm_info* out) {
  if (!h || !out || out->struct_size != (int32_t)sizeof(*out)) return VV_E_INVALID_ARG;
  out->used_gpu = h->L.used_gpu;
  out->used_kv_quant = h->L.used_kv_quant;
  out->fallbacks = h->L.fallbacks;
  out->n_ctx = h->n_ctx;
  out->n_threads = h->L.n_threads;
  out->load_ms = h->L.load_ms;
  out->model_bytes = llama_model_size(h->L.model);
  return VV_OK;
}

int32_t vv_llm_count_tokens(vv_llm* h, const char* text, int32_t* out) {
  if (!h || !text || !out) return VV_E_INVALID_ARG;
  try {
    const llama_vocab* vocab = llama_model_get_vocab(h->L.model);
    int n = -llama_tokenize(vocab, text, (int32_t)strlen(text), nullptr, 0, true, true);
    if (n < 0) return VV_E_INTERNAL;
    *out = n;
    return VV_OK;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_llm_apply_chat_template(vv_llm* h, const vv_chat_msg* msgs, size_t n, char** out) {
  if (!h || !msgs || n == 0 || !out) return VV_E_INVALID_ARG;
  *out = nullptr;
  try {
    const char* tmpl = llama_model_chat_template(h->L.model, nullptr);
    if (!tmpl) return VV_E_INVALID_ARG;
    std::vector<llama_chat_message> chat(n);
    size_t total = 0;
    for (size_t i = 0; i < n; i++) {
      if (!msgs[i].role || !msgs[i].content) return VV_E_INVALID_ARG;
      chat[i] = {msgs[i].role, msgs[i].content};
      total += strlen(msgs[i].content) + strlen(msgs[i].role);
    }
    std::vector<char> buf(total * 2 + 512);
    int32_t len = llama_chat_apply_template(tmpl, chat.data(), n, true, buf.data(), (int32_t)buf.size());
    if (len < 0) return VV_E_INVALID_ARG;  // template not supported without jinja
    if ((size_t)len > buf.size()) {
      buf.resize(len);
      len = llama_chat_apply_template(tmpl, chat.data(), n, true, buf.data(), (int32_t)buf.size());
      if (len < 0) return VV_E_INVALID_ARG;
    }
    char* s = dup_cstr(std::string(buf.data(), len));
    if (!s) return VV_E_OOM;
    *out = s;
    return VV_OK;
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_llm_generate_async(vv_llm* h, const char* prompt, const vv_gen_params* params,
                              vv_llm_callbacks callbacks) {
  if (!h || !prompt || !params || params->struct_size != (int32_t)sizeof(*params) ||
      params->n_predict < 1 || params->token_batch < 1) {
    return VV_E_INVALID_ARG;
  }
  bool expected = false;
  if (!h->busy.compare_exchange_strong(expected, true)) return VV_E_BUSY;
  try {
    std::lock_guard<std::mutex> lock(h->mu);
    if (h->worker.joinable()) h->worker.join();  // previous job already reported done
    bool grammar_ok = true;
    llama_sampler* grammar = nullptr;
    llama_sampler* chain =
        build_chain(llama_model_get_vocab(h->L.model), *params, &grammar_ok, &grammar);
    if (!chain) {
      h->busy.store(false);
      return grammar_ok ? VV_E_INTERNAL : VV_E_INVALID_ARG;
    }
    h->cancel.store(false);
    Job j{h, std::string(prompt), *params, chain, grammar, callbacks, 0, {}};
    j.g.grammar = nullptr;  // only used while building the chain
    h->worker = std::thread(worker_main, std::move(j));
    return VV_OK;
  } catch (const std::bad_alloc&) {
    h->busy.store(false);
    return VV_E_OOM;
  } catch (...) {
    h->busy.store(false);
    return VV_E_INTERNAL;
  }
}

void vv_llm_cancel(vv_llm* h) {
  if (h) h->cancel.store(true);
}

void vv_llm_destroy(vv_llm* h) {
  if (!h) return;
  h->cancel.store(true);
  {
    std::lock_guard<std::mutex> lock(h->mu);
    if (h->worker.joinable()) h->worker.join();
  }
  delete h;  // ~Loaded frees context, threadpool, model
}

}  // extern "C"
