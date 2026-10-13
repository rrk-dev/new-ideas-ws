// [STT-03] whisper.cpp behind the vv_stt_* C ABI (see vv_whisper.h).
#include "vv_whisper.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <thread>
#include <vector>

#include "vv_bridge.h"
#include "vv_wav.h"
#include "whisper.h"

struct vv_stt {
  whisper_context* ctx = nullptr;
  std::thread worker;
  std::atomic<bool> cancel{false};
  std::atomic<bool> busy{false};
  std::mutex worker_mu;  // guards worker (start / destroy)
  std::mutex err_mu;     // guards last_error (also taken by the worker)
  std::string last_error;
};

namespace {

thread_local std::string t_create_error;

void set_error(vv_stt* h, const char* msg) {
  if (!h) {
    t_create_error = msg;
    return;
  }
  std::lock_guard<std::mutex> lock(h->err_mu);
  h->last_error = msg;
}

char* dup(const char* s) {
  const size_t n = std::strlen(s ? s : "");
  char* out = static_cast<char*>(std::malloc(n + 1));
  if (!out) throw std::bad_alloc();
  std::memcpy(out, s ? s : "", n + 1);
  return out;
}

struct Range {
  std::string path;
  int64_t start_ms;
  int64_t end_ms;
};

// Where each range starts on the concatenated timeline.
struct Span {
  int64_t timeline_ms;  // first sample of this range on the timeline
  int64_t src_ms;       // same sample in the source file
  int64_t len_ms;
};

struct Job {
  vv_stt* h;
  std::vector<Range> ranges;
  // Owned copies of the string params.
  std::string language, prompt;
  bool has_prompt = false;
  vv_stt_params p;
  vv_stt_callbacks cbs;
  void* user;
  std::vector<Span> spans;
  int32_t next_index = 0;
  int32_t delivered = 0;  // on_segment calls made (reported in on_done)
  whisper_token eot = 0;
};

void map_time(const Job& job, int64_t t, int32_t* range, int64_t* src) {
  size_t i = 0;
  while (i + 1 < job.spans.size() && job.spans[i + 1].timeline_ms <= t) ++i;
  if (job.spans.empty()) {
    *range = 0;
    *src = t;
    return;
  }
  const Span& s = job.spans[i];
  const int64_t off = std::min(std::max<int64_t>(t - s.timeline_ms, 0), s.len_ms);
  *range = static_cast<int32_t>(i);
  *src = s.src_ms + off;
}

vv_stt_segment* make_segment(Job& job, whisper_context* ctx, int i) {
  auto* seg = static_cast<vv_stt_segment*>(std::calloc(1, sizeof(vv_stt_segment)));
  if (!seg) throw std::bad_alloc();
  seg->index = job.next_index++;
  seg->t0_ms = whisper_full_get_segment_t0(ctx, i) * 10;  // 10 ms units
  seg->t1_ms = whisper_full_get_segment_t1(ctx, i) * 10;
  if (seg->t1_ms < seg->t0_ms) seg->t1_ms = seg->t0_ms;
  map_time(job, seg->t0_ms, &seg->t0_range, &seg->t0_src_ms);
  map_time(job, seg->t1_ms, &seg->t1_range, &seg->t1_src_ms);
  seg->no_speech_prob = whisper_full_get_segment_no_speech_prob(ctx, i);
  seg->text = dup(whisper_full_get_segment_text(ctx, i));
  const int nt = whisper_full_n_tokens(ctx, i);
  double sum = 0;
  int n = 0;
  std::vector<vv_stt_token> toks;
  for (int j = 0; j < nt; ++j) {
    const whisper_token_data d = whisper_full_get_token_data(ctx, i, j);
    if (d.id >= job.eot) continue;  // special / timestamp tokens
    sum += d.plog;
    ++n;
    if (job.p.token_timestamps) {
      vv_stt_token t;
      t.text = dup(whisper_full_get_token_text(ctx, i, j));
      t.p = d.p;
      t.t0_ms = d.t0 >= 0 ? d.t0 * 10 : -1;
      t.t1_ms = d.t1 >= 0 ? d.t1 * 10 : -1;
      toks.push_back(t);
    }
  }
  seg->avg_logprob = n ? static_cast<float>(sum / n) : 0.0f;
  if (!toks.empty()) {
    seg->tokens = static_cast<vv_stt_token*>(std::malloc(toks.size() * sizeof(vv_stt_token)));
    if (!seg->tokens) throw std::bad_alloc();
    std::memcpy(seg->tokens, toks.data(), toks.size() * sizeof(vv_stt_token));
    seg->n_tokens = static_cast<int32_t>(toks.size());
  }
  return seg;
}

void on_new_segment(whisper_context* ctx, whisper_state*, int n_new, void* user) {
  Job& job = *static_cast<Job*>(user);
  if (!job.cbs.on_segment) return;
  const int n = whisper_full_n_segments(ctx);
  for (int i = n - n_new; i < n; ++i) {
    try {
      job.cbs.on_segment(job.user, make_segment(job, ctx, i));
      ++job.delivered;
    } catch (...) {
      // Out of memory while copying: drop the event, the job continues.
    }
  }
}

void on_progress(whisper_context*, whisper_state*, int progress, void* user) {
  Job& job = *static_cast<Job*>(user);
  if (job.cbs.on_progress) job.cbs.on_progress(job.user, std::clamp(progress, 0, 100));
}

bool on_abort(void* user) { return static_cast<Job*>(user)->h->cancel.load(); }

bool on_encoder_begin(whisper_context*, whisper_state*, void* user) {
  return !static_cast<Job*>(user)->h->cancel.load();
}

int64_t now_ms() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count();
}

void run_job(Job* job_ptr) {
  Job& job = *job_ptr;
  vv_stt* h = job.h;
  const int64_t t_start = now_ms();
  int32_t status = VV_OK;
  int64_t audio_ms = 0;
  try {
    std::vector<float> pcm;
    for (const Range& r : job.ranges) {
      if (h->cancel.load()) break;
      const size_t before = pcm.size();
      const vv::WavStatus st = vv::wav_read_range(r.path.c_str(), r.start_ms, r.end_ms, &pcm);
      if (st != vv::WavStatus::ok) {
        status = st == vv::WavStatus::io ? VV_E_IO : VV_E_INVALID_ARG;
        set_error(h, st == vv::WavStatus::io ? "audio file not readable"
                                              : "audio must be 16 kHz PCM16 WAV");
        break;
      }
      const int64_t len_ms =
          static_cast<int64_t>((pcm.size() - before) * 1000 / vv::kWavSampleRate);
      Span s;
      s.timeline_ms = static_cast<int64_t>(before * 1000 / vv::kWavSampleRate);
      s.src_ms = std::max<int64_t>(r.start_ms, 0);
      s.len_ms = len_ms;
      job.spans.push_back(s);
    }
    audio_ms = static_cast<int64_t>(pcm.size() * 1000 / vv::kWavSampleRate);
    if (status == VV_OK && h->cancel.load()) status = VV_E_CANCELLED;
    if (status == VV_OK && !pcm.empty()) {
      whisper_full_params wp = whisper_full_default_params(
          job.p.beam_size > 1 ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY);
      int threads = job.p.n_threads;
      if (threads <= 0) threads = std::min(vv_cpu_perf_cores(), 4);
      wp.n_threads = std::max(threads, 1);
      wp.language = job.language.c_str();
      wp.detect_language = false;
      wp.translate = job.p.translate != 0;
      wp.no_context = job.p.no_context != 0;
      wp.token_timestamps = job.p.token_timestamps != 0;
      wp.suppress_nst = job.p.suppress_nst != 0;
      wp.temperature = job.p.temperature;
      wp.temperature_inc = job.p.temperature_inc;
      wp.entropy_thold = job.p.entropy_thold;
      wp.logprob_thold = job.p.logprob_thold;
      wp.no_speech_thold = job.p.no_speech_thold;
      if (job.p.beam_size > 1) wp.beam_search.beam_size = job.p.beam_size;
      wp.initial_prompt = job.has_prompt ? job.prompt.c_str() : nullptr;
      wp.carry_initial_prompt = job.has_prompt && job.p.carry_initial_prompt != 0;
      wp.print_progress = false;
      wp.print_realtime = false;
      wp.print_timestamps = false;
      wp.print_special = false;
      wp.new_segment_callback = on_new_segment;
      wp.new_segment_callback_user_data = &job;
      wp.progress_callback = on_progress;
      wp.progress_callback_user_data = &job;
      wp.abort_callback = on_abort;
      wp.abort_callback_user_data = &job;
      wp.encoder_begin_callback = on_encoder_begin;
      wp.encoder_begin_callback_user_data = &job;
      job.eot = whisper_token_eot(h->ctx);
      const int rc = whisper_full(h->ctx, wp, pcm.data(), static_cast<int>(pcm.size()));
      if (h->cancel.load()) {
        status = VV_E_CANCELLED;
      } else if (rc != 0) {
        status = VV_E_INTERNAL;
        set_error(h, "whisper_full failed");
      }
    }
  } catch (const std::bad_alloc&) {
    status = VV_E_OOM;
    set_error(h, "out of memory");
  } catch (...) {
    status = VV_E_INTERNAL;
    set_error(h, "internal error");
  }
  const vv_stt_done_cb done = job.cbs.on_done;
  void* user = job.user;
  const int32_t n_segments = job.delivered;
  delete job_ptr;
  // Not busy any more *before* on_done: a caller reacting to on_done may
  // start the next job right away.
  h->busy.store(false);
  done(user, status, audio_ms, now_ms() - t_start, n_segments);
}

int32_t start(vv_stt* h, std::vector<Range> ranges, const vv_stt_params* params,
              vv_stt_callbacks cbs, void* user) {
  if (!h || !params || params->struct_size < sizeof(vv_stt_params) || !cbs.on_done ||
      ranges.empty()) {
    if (h) set_error(h, "invalid argument");
    return VV_E_INVALID_ARG;
  }
  for (const Range& r : ranges) {
    if (r.path.empty()) {
      set_error(h, "invalid argument");
      return VV_E_INVALID_ARG;
    }
  }
  if (h->busy.exchange(true)) {
    set_error(h, "a transcription is already running");
    return VV_E_BUSY;
  }
  std::lock_guard<std::mutex> lock(h->worker_mu);
  if (h->worker.joinable()) h->worker.join();  // previous job already finished
  h->cancel.store(false);
  auto* job = new Job();
  job->h = h;
  job->ranges = std::move(ranges);
  job->p = *params;
  job->language = params->language && *params->language ? params->language : "en";
  job->has_prompt = params->initial_prompt && *params->initial_prompt;
  if (job->has_prompt) job->prompt = params->initial_prompt;
  job->cbs = cbs;
  job->user = user;
  try {
    h->worker = std::thread(run_job, job);
  } catch (...) {
    delete job;
    h->busy.store(false);
    set_error(h, "could not start worker thread");
    return VV_E_INTERNAL;
  }
  return VV_OK;
}

}  // namespace

extern "C" {

vv_stt_init_params vv_stt_default_init_params(void) {
  vv_stt_init_params p;
  std::memset(&p, 0, sizeof(p));
  p.struct_size = sizeof(p);
  p.use_gpu = 1;
  p.flash_attn = 0;
  p.gpu_device = 0;
  return p;
}

vv_stt_params vv_stt_default_params(void) {
  vv_stt_params p;
  std::memset(&p, 0, sizeof(p));
  p.struct_size = sizeof(p);
  p.language = "en";
  p.translate = 0;
  p.n_threads = 0;
  p.beam_size = 1;
  p.temperature = 0.0f;
  p.temperature_inc = 0.2f;
  p.initial_prompt = nullptr;
  p.carry_initial_prompt = 1;
  p.no_context = 1;
  p.token_timestamps = 0;
  p.suppress_nst = 1;
  p.entropy_thold = 2.4f;
  p.logprob_thold = -1.0f;
  p.no_speech_thold = 0.6f;
  return p;
}

int32_t vv_stt_create(const char* model_path, const vv_stt_init_params* params, vv_stt** out) {
  if (out) *out = nullptr;
  if (!model_path || !*model_path || !out ||
      (params && params->struct_size < sizeof(vv_stt_init_params))) {
    set_error(nullptr, "invalid argument");
    return VV_E_INVALID_ARG;
  }
  try {
    const vv_stt_init_params ip = params ? *params : vv_stt_default_init_params();
    whisper_context_params cp = whisper_context_default_params();
    cp.use_gpu = ip.use_gpu != 0;
    cp.flash_attn = ip.flash_attn != 0;
    cp.gpu_device = ip.gpu_device;
    whisper_context* ctx = whisper_init_from_file_with_params(model_path, cp);
    if (!ctx) {
      set_error(nullptr, "model could not be loaded");
      return VV_E_MODEL_LOAD;
    }
    auto* h = new vv_stt();
    h->ctx = ctx;
    *out = h;
    return VV_OK;
  } catch (const std::bad_alloc&) {
    set_error(nullptr, "out of memory");
    return VV_E_OOM;
  } catch (...) {
    set_error(nullptr, "internal error");
    return VV_E_INTERNAL;
  }
}

int32_t vv_stt_transcribe_async(vv_stt* h, const char* wav_path, const vv_stt_params* params,
                                vv_stt_callbacks cbs, void* user) {
  try {
    if (!wav_path) return start(h, {}, params, cbs, user);
    return start(h, {Range{wav_path, 0, -1}}, params, cbs, user);
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

int32_t vv_stt_transcribe_ranges(vv_stt* h, const vv_audio_range* ranges, size_t n,
                                 const vv_stt_params* params, vv_stt_callbacks cbs, void* user) {
  try {
    std::vector<Range> rs;
    if (ranges) {
      rs.reserve(n);
      for (size_t i = 0; i < n; ++i)
        rs.push_back(Range{ranges[i].path ? ranges[i].path : "", ranges[i].start_ms, ranges[i].end_ms});
    }
    return start(h, std::move(rs), params, cbs, user);
  } catch (const std::bad_alloc&) {
    return VV_E_OOM;
  } catch (...) {
    return VV_E_INTERNAL;
  }
}

void vv_stt_cancel(vv_stt* h) {
  if (h) h->cancel.store(true);
}

void vv_stt_destroy(vv_stt* h) {
  if (!h) return;
  h->cancel.store(true);
  {
    std::lock_guard<std::mutex> lock(h->worker_mu);
    if (h->worker.joinable()) h->worker.join();
  }
  whisper_free(h->ctx);
  delete h;
}

void vv_stt_free_segment(vv_stt_segment* seg) {
  if (!seg) return;
  for (int32_t i = 0; i < seg->n_tokens; ++i) std::free(const_cast<char*>(seg->tokens[i].text));
  std::free(seg->tokens);
  std::free(const_cast<char*>(seg->text));
  std::free(seg);
}

const char* vv_stt_last_error(vv_stt* h) {
  if (!h) return t_create_error.c_str();
  std::lock_guard<std::mutex> lock(h->err_mu);
  return h->last_error.c_str();
}

}  // extern "C"
