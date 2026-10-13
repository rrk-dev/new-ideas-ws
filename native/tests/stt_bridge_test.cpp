// [STT-03] Host tests for the vv_stt_* C ABI (bridge/vv_whisper.cpp), using
// only the public header. Models: ggml-tiny.en.bin + jfk.wav from
// $VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh); exit 77 = skipped.
//   stt_bridge_test args      argument validation, bad model path (no models needed)
//   stt_bridge_test jfk       keywords, monotonic timestamps, progress, ownership
//   stt_bridge_test ranges    vv_stt_transcribe_ranges time mapping
//   stt_bridge_test busy      one job per handle
//   stt_bridge_test cancel    [STT-03/AC1] cancel stops within 1 s
//   stt_bridge_test destroy   destroy while running, destroy after cancel
//   stt_bridge_test audio     unreadable / non-WAV input
//   stt_bridge_test churn     repeated create/transcribe/destroy
// Set VV_STT_GPU=0 to force the CPU backend.
#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "vv_bridge.h"

namespace {

constexpr int kSkip = 77;

int fail(const char* what) {
  std::fprintf(stderr, "FAIL: %s\n", what);
  return 1;
}

int64_t now_ms() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count();
}

struct Seg {
  int32_t index, t0_range, t1_range;
  int64_t t0, t1, t0_src, t1_src;
  float avg_logprob, no_speech;
  std::string text;
  int32_t n_tokens;
};

struct Sink {
  std::mutex mu;
  std::condition_variable cv;
  bool done = false;
  int32_t status = 1;
  int64_t audio_ms = -1, process_ms = -1, done_at = 0;
  int64_t first_progress_at = 0;
  int32_t n_segments = -1;
  std::vector<int32_t> progress;
  std::vector<Seg> segs;
  bool callback_after_done = false;

  std::string text() {
    std::string t;
    for (auto& s : segs) t += s.text;
    for (auto& c : t) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return t;
  }
  bool wait(int64_t timeout_ms) {
    std::unique_lock<std::mutex> lock(mu);
    return cv.wait_for(lock, std::chrono::milliseconds(timeout_ms), [&] { return done; });
  }
};

void cb_progress(void* user, int32_t pct) {
  auto* s = static_cast<Sink*>(user);
  std::lock_guard<std::mutex> lock(s->mu);
  if (s->done) s->callback_after_done = true;
  if (s->progress.empty()) s->first_progress_at = now_ms();
  s->progress.push_back(pct);
}

void cb_segment(void* user, vv_stt_segment* seg) {
  auto* s = static_cast<Sink*>(user);
  {
    std::lock_guard<std::mutex> lock(s->mu);
    if (s->done) s->callback_after_done = true;
    s->segs.push_back(Seg{seg->index, seg->t0_range, seg->t1_range, seg->t0_ms, seg->t1_ms,
                          seg->t0_src_ms, seg->t1_src_ms, seg->avg_logprob, seg->no_speech_prob,
                          seg->text ? seg->text : "", seg->n_tokens});
  }
  vv_stt_free_segment(seg);  // callee owns the payload
}

void cb_done(void* user, int32_t status, int64_t audio_ms, int64_t process_ms, int32_t n_segments) {
  auto* s = static_cast<Sink*>(user);
  std::lock_guard<std::mutex> lock(s->mu);
  s->done = true;
  s->status = status;
  s->audio_ms = audio_ms;
  s->process_ms = process_ms;
  s->n_segments = n_segments;
  s->done_at = now_ms();
  s->cv.notify_all();
}

vv_stt_callbacks callbacks() {
  vv_stt_callbacks c;
  c.on_progress = cb_progress;
  c.on_segment = cb_segment;
  c.on_done = cb_done;
  return c;
}

std::string g_model, g_wav;

bool have_models() {
  const char* dir = std::getenv("VV_TEST_MODELS_DIR");
  if (!dir || !*dir) return false;
  g_model = std::string(dir) + "/ggml-tiny.en.bin";
  g_wav = std::string(dir) + "/jfk.wav";
  for (const auto& p : {g_model, g_wav}) {
    FILE* f = std::fopen(p.c_str(), "rb");
    if (!f) return false;
    std::fclose(f);
  }
  return true;
}

vv_stt* create() {
  vv_backends_load(nullptr, VV_GPU_METAL | VV_GPU_VULKAN | VV_GPU_OPENCL);
  vv_stt_init_params ip = vv_stt_default_init_params();
  const char* gpu = std::getenv("VV_STT_GPU");
  if (gpu && std::strcmp(gpu, "0") == 0) ip.use_gpu = 0;
  vv_stt* h = nullptr;
  if (vv_stt_create(g_model.c_str(), &ip, &h) != VV_OK) return nullptr;
  return h;
}

int args() {
  vv_stt* h = reinterpret_cast<vv_stt*>(0x1);
  if (vv_stt_create(nullptr, nullptr, &h) != VV_E_INVALID_ARG || h != nullptr) return fail("NULL path");
  if (vv_stt_create("/nonexistent/ggml-x.bin", nullptr, &h) != VV_E_MODEL_LOAD || h) return fail("bad path");
  if (std::strlen(vv_stt_last_error(nullptr)) == 0) return fail("create error message");
  vv_stt_init_params bad = vv_stt_default_init_params();
  bad.struct_size = 4;
  if (vv_stt_create("/x", &bad, &h) != VV_E_INVALID_ARG) return fail("struct_size");
  const vv_stt_params p = vv_stt_default_params();
  Sink s;
  if (vv_stt_transcribe_async(nullptr, "/x.wav", &p, callbacks(), &s) != VV_E_INVALID_ARG)
    return fail("NULL handle");
  vv_stt_cancel(nullptr);
  vv_stt_destroy(nullptr);
  vv_stt_free_segment(nullptr);
  if (p.struct_size != sizeof(vv_stt_params) || std::strcmp(p.language, "en") != 0 || p.no_context != 1 ||
      p.translate != 0 || p.suppress_nst != 1)
    return fail("default params");
  if (!have_models()) {
    std::printf("args OK (model-dependent checks skipped)\n");
    return 0;
  }
  vv_stt* m = create();
  if (!m) return fail("create tiny.en");
  vv_stt_callbacks no_done = callbacks();
  no_done.on_done = nullptr;
  if (vv_stt_transcribe_async(m, g_wav.c_str(), &p, no_done, &s) != VV_E_INVALID_ARG) return fail("no on_done");
  vv_stt_params small = p;
  small.struct_size = 8;
  if (vv_stt_transcribe_async(m, g_wav.c_str(), &small, callbacks(), &s) != VV_E_INVALID_ARG)
    return fail("params struct_size");
  if (vv_stt_transcribe_ranges(m, nullptr, 0, &p, callbacks(), &s) != VV_E_INVALID_ARG) return fail("0 ranges");
  vv_stt_destroy(m);
  std::printf("args OK\n");
  return 0;
}

int jfk() {
  vv_stt* h = create();
  if (!h) return fail("create");
  Sink s;
  vv_stt_params p = vv_stt_default_params();
  p.token_timestamps = 1;
  const int64_t t0 = now_ms();
  if (vv_stt_transcribe_async(h, g_wav.c_str(), &p, callbacks(), &s) != VV_OK) return fail("start");
  if (now_ms() - t0 > 50) return fail("transcribe_async must return immediately");
  if (!s.wait(60000)) return fail("timeout");
  if (s.status != VV_OK) return fail("status");
  const std::string t = s.text();
  if (t.find("ask not") == std::string::npos || t.find("country") == std::string::npos)
    return fail("jfk keywords");
  if (s.segs.empty()) return fail("no segments");
  int64_t prev_end = 0;
  for (size_t i = 0; i < s.segs.size(); ++i) {
    const Seg& g = s.segs[i];
    if (g.index != static_cast<int32_t>(i)) return fail("segment index order");
    if (g.t0 < prev_end || g.t1 < g.t0) return fail("timestamps not monotonic");
    if (g.t1 > 11100) return fail("timestamp beyond the 11 s clip");
    if (g.t0_range != 0 || g.t0_src != g.t0 || g.t1_src != g.t1) return fail("single-file mapping");
    if (!(g.avg_logprob < 0.0f) || g.avg_logprob < -5.0f) return fail("avg_logprob range");
    if (g.n_tokens <= 0) return fail("token timestamps requested but no tokens");
    prev_end = g.t1;
  }
  if (s.progress.empty() || s.progress.back() > 100) return fail("progress");
  if (!std::is_sorted(s.progress.begin(), s.progress.end())) return fail("progress not monotonic");
  if (s.audio_ms < 10900 || s.audio_ms > 11100) return fail("audio_ms");
  if (s.callback_after_done) return fail("callback after on_done");
  if (s.n_segments != static_cast<int32_t>(s.segs.size())) return fail("n_segments in on_done");
  vv_stt_destroy(h);
  std::printf("jfk OK: %zu segment(s), audio %lld ms, processed in %lld ms\n", s.segs.size(),
              static_cast<long long>(s.audio_ms), static_cast<long long>(s.process_ms));
  return 0;
}

int ranges() {
  vv_stt* h = create();
  if (!h) return fail("create");
  // Window = jfk[0, 11 s) followed by jfk[2 s, end) of the "next chunk".
  const vv_audio_range r[] = {{g_wav.c_str(), 0, -1}, {g_wav.c_str(), 2000, -1}};
  Sink s;
  const vv_stt_params p = vv_stt_default_params();
  if (vv_stt_transcribe_ranges(h, r, 2, &p, callbacks(), &s) != VV_OK) return fail("start");
  if (!s.wait(60000) || s.status != VV_OK) return fail("ranges status");
  if (s.audio_ms < 19800 || s.audio_ms > 20200) return fail("concatenated length");
  bool saw_second = false;
  for (const Seg& g : s.segs) {
    if (g.t0_range < 0 || g.t0_range > 1 || g.t1_range < g.t0_range) return fail("range index");
    if (g.t0_range == 0 && g.t0_src != g.t0) return fail("range 0 mapping");
    if (g.t0_range == 1) {
      saw_second = true;
      // timeline 11 s == file 2 s of the second range.
      if (g.t0_src != 2000 + (g.t0 - 11000) || g.t0 < 11000) return fail("range 1 mapping");
    }
    if (g.t1_src > 11100) return fail("src time beyond file");
  }
  if (!saw_second) return fail("no segment in the second range");
  const std::string t = s.text();
  size_t n = 0;
  for (size_t pos = t.find("country"); pos != std::string::npos; pos = t.find("country", pos + 1)) ++n;
  if (n < 3) return fail("expected both copies transcribed");
  vv_stt_destroy(h);
  std::printf("ranges OK: %zu segment(s)\n", s.segs.size());
  return 0;
}

int busy() {
  vv_stt* h = create();
  if (!h) return fail("create");
  Sink a, b;
  const vv_stt_params p = vv_stt_default_params();
  if (vv_stt_transcribe_async(h, g_wav.c_str(), &p, callbacks(), &a) != VV_OK) return fail("first");
  if (vv_stt_transcribe_async(h, g_wav.c_str(), &p, callbacks(), &b) != VV_E_BUSY) return fail("second must be BUSY");
  if (!a.wait(60000) || a.status != VV_OK) return fail("first job");
  // Next job after on_done must be accepted.
  if (vv_stt_transcribe_async(h, g_wav.c_str(), &p, callbacks(), &b) != VV_OK) return fail("after done");
  if (!b.wait(60000) || b.status != VV_OK) return fail("second job");
  vv_stt_destroy(h);
  std::printf("busy OK\n");
  return 0;
}

int cancel() {
  vv_stt* h = create();
  if (!h) return fail("create");
  // ~5.5 min of audio so the job is certainly still running when cancelled.
  std::vector<vv_audio_range> r(30, vv_audio_range{g_wav.c_str(), 0, -1});
  Sink s;
  const vv_stt_params p = vv_stt_default_params();
  if (vv_stt_transcribe_ranges(h, r.data(), r.size(), &p, callbacks(), &s) != VV_OK) return fail("start");
  // Cancel once decoding is under way (first segment or 1.5 s, whichever first).
  for (int i = 0; i < 150; ++i) {
    {
      std::lock_guard<std::mutex> lock(s.mu);
      if (!s.segs.empty() || s.done) break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  const int64_t t_cancel = now_ms();
  vv_stt_cancel(h);
  if (now_ms() - t_cancel > 5) return fail("cancel must return immediately");
  if (!s.wait(5000)) return fail("no on_done after cancel");
  const int64_t latency = s.done_at - t_cancel;
  if (s.status != VV_E_CANCELLED) return fail("status must be VV_E_CANCELLED");
  if (latency >= 1000) {
    std::fprintf(stderr, "cancel latency %lld ms\n", static_cast<long long>(latency));
    return fail("[STT-03/AC1] cancel must stop within 1 s");
  }
  // The handle stays usable after a cancelled job.
  Sink again;
  if (vv_stt_transcribe_async(h, g_wav.c_str(), &p, callbacks(), &again) != VV_OK) return fail("reuse");
  if (!again.wait(60000) || again.status != VV_OK) return fail("job after cancel");
  vv_stt_cancel(h);  // idle cancel is a no-op
  vv_stt_destroy(h);  // destroy after cancel
  std::printf("cancel OK: latency %lld ms (%zu segment(s) before cancel)\n",
              static_cast<long long>(latency), s.segs.size());
  return 0;
}

int destroy() {
  vv_stt* h = create();
  if (!h) return fail("create");
  std::vector<vv_audio_range> r(10, vv_audio_range{g_wav.c_str(), 0, -1});
  Sink s;
  const vv_stt_params p = vv_stt_default_params();
  if (vv_stt_transcribe_ranges(h, r.data(), r.size(), &p, callbacks(), &s) != VV_OK) return fail("start");
  const int64_t t = now_ms();
  vv_stt_destroy(h);  // must cancel + join
  if (!s.done) return fail("on_done must have fired before destroy returns");
  if (s.status != VV_E_CANCELLED && s.status != VV_OK) return fail("status after destroy");
  if (now_ms() - t > 2000) return fail("destroy took too long");
  std::printf("destroy OK (%lld ms)\n", static_cast<long long>(now_ms() - t));
  return 0;
}

int audio() {
  vv_stt* h = create();
  if (!h) return fail("create");
  const vv_stt_params p = vv_stt_default_params();
  Sink missing, notwav;
  if (vv_stt_transcribe_async(h, "/nonexistent/x.wav", &p, callbacks(), &missing) != VV_OK) return fail("start");
  if (!missing.wait(10000) || missing.status != VV_E_IO) return fail("missing file -> VV_E_IO");
  if (vv_stt_transcribe_async(h, g_model.c_str(), &p, callbacks(), &notwav) != VV_OK) return fail("start 2");
  if (!notwav.wait(10000) || notwav.status != VV_E_INVALID_ARG) return fail("non-WAV -> VV_E_INVALID_ARG");
  if (std::strlen(vv_stt_last_error(h)) == 0) return fail("error message");
  vv_stt_destroy(h);
  std::printf("audio OK\n");
  return 0;
}

int churn() {
  for (int i = 0; i < 10; ++i) {
    vv_stt* h = create();
    if (!h) return fail("create");
    if (i % 3 == 0) {
      Sink s;
      const vv_stt_params p = vv_stt_default_params();
      if (vv_stt_transcribe_async(h, g_wav.c_str(), &p, callbacks(), &s) != VV_OK) return fail("start");
      if (i % 2 == 0) vv_stt_cancel(h);
      if (!s.wait(60000)) return fail("done");
    }
    vv_stt_destroy(h);
  }
  std::printf("churn OK\n");
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
  const std::string m = argc > 1 ? argv[1] : "";
  if (m == "args") return args();
  if (!have_models()) {
    std::printf("SKIP: set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)\n");
    return kSkip;
  }
  if (m == "jfk") return jfk();
  if (m == "ranges") return ranges();
  if (m == "busy") return busy();
  if (m == "cancel") return cancel();
  if (m == "destroy") return destroy();
  if (m == "audio") return audio();
  if (m == "churn") return churn();
  std::fprintf(stderr, "unknown mode\n");
  return 64;
}
