// [AUD-03] Host tests for the vv_vad_* C ABI and the VAD fields of
// vv_stt_params (bridge/vv_vad.cpp, bridge/vv_whisper.cpp), public header
// only (+ vv_wav.h to read the sample). Models from $VV_TEST_MODELS_DIR
// (tools/ci/fetch_test_models.sh): ggml-silero-v6.2.0.bin, ggml-tiny.en.bin,
// jfk.wav; exit 77 = skipped when missing.
//   vad_test args       argument validation, bad model path (no models)
//   vad_test segments   silence -> no segments; jfk -> speech covering the words
//   vad_test stream     vv_vad_feed: silence -> no speech windows, speech -> some;
//                       one window per 512 samples across uneven feeds; reset
//   vad_test stt_silence [AUD-03/AC2] 30 s silence + VAD -> no transcript text
//   vad_test stt_mapped  silence + jfk + silence with VAD: words found, segment
//                        times on the ORIGINAL timeline (>= leading silence)
//   vad_test stt_v1      a caller using the STT-03 struct layout still works
#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include "vv_bridge.h"
#include "vv_wav.h"

namespace {

constexpr int kSkip = 77;
std::string g_dir, g_vad, g_stt, g_jfk;

int fail(const char* what) {
  std::fprintf(stderr, "FAIL: %s\n", what);
  return 1;
}

bool exists(const std::string& p) {
  FILE* f = std::fopen(p.c_str(), "rb");
  if (!f) return false;
  std::fclose(f);
  return true;
}

bool have(bool need_stt) {
  const char* dir = std::getenv("VV_TEST_MODELS_DIR");
  if (!dir || !*dir) return false;
  g_dir = dir;
  g_vad = g_dir + "/ggml-silero-v6.2.0.bin";
  g_stt = g_dir + "/ggml-tiny.en.bin";
  g_jfk = g_dir + "/jfk.wav";
  if (!exists(g_vad) || !exists(g_jfk)) return false;
  return !need_stt || exists(g_stt);
}

void put32(FILE* f, uint32_t v) {
  uint8_t b[4] = {uint8_t(v), uint8_t(v >> 8), uint8_t(v >> 16), uint8_t(v >> 24)};
  std::fwrite(b, 1, 4, f);
}
void put16(FILE* f, uint16_t v) {
  uint8_t b[2] = {uint8_t(v), uint8_t(v >> 8)};
  std::fwrite(b, 1, 2, f);
}

// Writes 16 kHz mono PCM16 WAV.
std::string write_wav(const char* name, const std::vector<float>& pcm) {
  const char* tmp = std::getenv("TMPDIR");
  std::string path = std::string(tmp && *tmp ? tmp : "/tmp") + "/vv_vad_" + name + ".wav";
  FILE* f = std::fopen(path.c_str(), "wb");
  const uint32_t data = static_cast<uint32_t>(pcm.size() * 2);
  std::fwrite("RIFF", 1, 4, f);
  put32(f, 36 + data);
  std::fwrite("WAVEfmt ", 1, 8, f);
  put32(f, 16);
  put16(f, 1);
  put16(f, 1);
  put32(f, 16000);
  put32(f, 32000);
  put16(f, 2);
  put16(f, 16);
  std::fwrite("data", 1, 4, f);
  put32(f, data);
  for (float x : pcm) {
    const int v = std::clamp(static_cast<int>(x * 32767.0f), -32768, 32767);
    put16(f, static_cast<uint16_t>(static_cast<int16_t>(v)));
  }
  std::fclose(f);
  return path;
}

std::vector<float> jfk() {
  std::vector<float> pcm;
  vv::wav_read_range(g_jfk.c_str(), 0, -1, &pcm);
  return pcm;
}

vv_vad* vad() {
  vv_vad* h = nullptr;
  vv_vad_params p = vv_vad_default_params();
  if (vv_vad_create(g_vad.c_str(), &p, &h) != VV_OK) return nullptr;
  return h;
}

// Count of {"start_ms":..} objects and the first/last bounds.
struct Parsed {
  int n = 0;
  long long first_start = -1, last_end = -1;
};
Parsed parse(const char* json) {
  Parsed p;
  const char* s = json;
  while ((s = std::strstr(s, "\"start_ms\":")) != nullptr) {
    long long a = std::atoll(s + 11);
    const char* e = std::strstr(s, "\"end_ms\":");
    long long b = std::atoll(e + 9);
    if (p.n == 0) p.first_start = a;
    p.last_end = b;
    ++p.n;
    s = e;
  }
  return p;
}

int args() {
  vv_vad* h = nullptr;
  if (vv_vad_create(nullptr, nullptr, &h) != VV_E_INVALID_ARG) return fail("null path");
  if (vv_vad_create("/nonexistent/vad.bin", nullptr, &h) != VV_E_MODEL_LOAD || h)
    return fail("bad model path");
  if (std::strlen(vv_vad_last_error(nullptr)) == 0) return fail("create error message");
  vv_vad_params small = vv_vad_default_params();
  small.struct_size = 4;
  if (vv_vad_create("x", &small, &h) != VV_E_INVALID_ARG) return fail("struct_size");
  char* json = nullptr;
  if (vv_vad_segments(nullptr, nullptr, 0, &json) != VV_E_INVALID_ARG) return fail("segments args");
  vv_vad_feed_result r;
  if (vv_vad_feed(nullptr, nullptr, 0, &r) != VV_E_INVALID_ARG) return fail("feed args");
  vv_vad_destroy(nullptr);
  vv_vad_reset(nullptr);
  const vv_vad_params d = vv_vad_default_params();
  if (d.threshold != 0.5f || d.min_speech_ms != 250 || d.min_silence_ms != 500 ||
      d.speech_pad_ms != 200)
    return fail("defaults");
  const vv_stt_params sp = vv_stt_default_params();
  if (sp.vad_model_path != nullptr || sp.vad_threshold != 0.5f) return fail("stt vad defaults");
  return 0;
}

int segments() {
  if (!have(false)) return kSkip;
  vv_vad* h = vad();
  if (!h) return fail("create");
  const std::string silence = write_wav("silence", std::vector<float>(16000 * 10, 0.0f));
  vv_audio_range r{silence.c_str(), 0, -1};
  char* json = nullptr;
  if (vv_vad_segments(h, &r, 1, &json) != VV_OK) return fail("segments silence");
  if (parse(json).n != 0) return fail("silence produced speech");
  vv_free_string(json);

  vv_audio_range s{g_jfk.c_str(), 0, -1};
  if (vv_vad_segments(h, &s, 1, &json) != VV_OK) return fail("segments jfk");
  const Parsed p = parse(json);
  std::printf("jfk segments: %s\n", json);
  vv_free_string(json);
  // jfk.wav: ~11 s, speech from ~0.3 s to ~10.5 s.
  if (p.n < 1) return fail("no speech in jfk");
  if (p.first_start > 1500 || p.last_end < 9000 || p.last_end > 11100) return fail("jfk bounds");

  vv_audio_range bad{"/nonexistent.wav", 0, -1};
  if (vv_vad_segments(h, &bad, 1, &json) != VV_E_IO) return fail("missing file");
  vv_vad_destroy(h);
  return 0;
}

int stream() {
  if (!have(false)) return kSkip;
  vv_vad* h = vad();
  if (!h) return fail("create");
  std::vector<int16_t> zeros(16000 * 3, 0);
  vv_vad_feed_result r;
  int windows = 0, speech = 0;
  // Uneven feeds: 1000 samples at a time -> 93 windows for 48000 samples.
  for (size_t i = 0; i < zeros.size(); i += 1000) {
    const size_t n = std::min<size_t>(1000, zeros.size() - i);
    if (vv_vad_feed(h, zeros.data() + i, n, &r) != VV_OK) return fail("feed");
    windows += r.windows;
    speech += r.speech_windows;
  }
  if (windows != 48000 / 512) return fail("window count");
  if (speech != 0) return fail("silence flagged as speech");
  if (vv_vad_feed(h, zeros.data(), 100, &r) != VV_OK || r.windows != 0 || r.max_prob != -1.0f)
    return fail("partial window");
  vv_vad_reset(h);

  const std::vector<float> f = jfk();
  std::vector<int16_t> pcm(f.size());
  for (size_t i = 0; i < f.size(); ++i) pcm[i] = static_cast<int16_t>(f[i] * 32767.0f);
  windows = speech = 0;
  const auto t0 = std::chrono::steady_clock::now();
  for (size_t i = 0; i < pcm.size(); i += 16000) {  // 1 s per call, like the app
    const size_t n = std::min<size_t>(16000, pcm.size() - i);
    if (vv_vad_feed(h, pcm.data() + i, n, &r) != VV_OK) return fail("feed jfk");
    windows += r.windows;
    speech += r.speech_windows;
  }
  const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                      std::chrono::steady_clock::now() - t0)
                      .count();
  std::printf("stream: %d/%d speech windows, %lld ms for %zu ms audio\n", speech, windows,
              static_cast<long long>(ms), pcm.size() / 16);
  if (speech < windows / 2) return fail("speech not detected while streaming");
  vv_vad_destroy(h);
  return 0;
}

struct Sink {
  std::mutex mu;
  std::condition_variable cv;
  bool done = false;
  int32_t status = 1;
  std::string text;
  std::vector<std::pair<int64_t, int64_t>> times;
};
void on_seg(void* u, vv_stt_segment* seg) {
  auto* s = static_cast<Sink*>(u);
  {
    std::lock_guard<std::mutex> l(s->mu);
    s->text += seg->text ? seg->text : "";
    s->times.emplace_back(seg->t0_ms, seg->t1_ms);
  }
  vv_stt_free_segment(seg);
}
void on_done(void* u, int32_t status, int64_t, int64_t, int32_t) {
  auto* s = static_cast<Sink*>(u);
  std::lock_guard<std::mutex> l(s->mu);
  s->done = true;
  s->status = status;
  s->cv.notify_all();
}

int transcribe(const std::string& wav, const vv_stt_params& p, Sink* sink) {
  vv_backends_load(nullptr, 0);
  vv_stt_init_params ip = vv_stt_default_init_params();
  ip.use_gpu = 0;
  vv_stt* h = nullptr;
  if (vv_stt_create(g_stt.c_str(), &ip, &h) != VV_OK) return fail("stt create");
  vv_stt_callbacks cbs{nullptr, on_seg, on_done};
  if (vv_stt_transcribe_async(h, wav.c_str(), &p, cbs, sink) != VV_OK) return fail("start");
  std::unique_lock<std::mutex> l(sink->mu);
  if (!sink->cv.wait_for(l, std::chrono::seconds(120), [&] { return sink->done; }))
    return fail("timeout");
  l.unlock();
  vv_stt_destroy(h);
  return sink->status == VV_OK ? 0 : fail("status");
}

int stt_silence() {
  if (!have(true)) return kSkip;
  // Low-level noise instead of digital zero: the classic hallucination case.
  std::vector<float> pcm(16000 * 30);
  uint32_t x = 1;
  for (auto& v : pcm) {
    x = x * 1664525u + 1013904223u;
    v = ((x >> 16) / 65536.0f - 0.5f) * 0.002f;
  }
  const std::string wav = write_wav("noise30", pcm);
  vv_stt_params p = vv_stt_default_params();
  p.vad_model_path = g_vad.c_str();
  Sink sink;
  if (int rc = transcribe(wav, p, &sink)) return rc;
  std::printf("silence with VAD: %zu segments, text='%s'\n", sink.times.size(), sink.text.c_str());
  if (!sink.text.empty() || !sink.times.empty()) return fail("text on silence with VAD");
  return 0;
}

int stt_mapped() {
  if (!have(true)) return kSkip;
  std::vector<float> pcm(16000 * 20, 0.0f);  // 20 s leading silence
  const std::vector<float> speech = jfk();
  pcm.insert(pcm.end(), speech.begin(), speech.end());
  pcm.insert(pcm.end(), 16000 * 20, 0.0f);
  const std::string wav = write_wav("padded", pcm);
  vv_stt_params p = vv_stt_default_params();
  p.vad_model_path = g_vad.c_str();
  p.token_timestamps = 1;
  Sink sink;
  if (int rc = transcribe(wav, p, &sink)) return rc;
  std::string t = sink.text;
  for (auto& c : t) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  std::printf("padded with VAD: '%s'\n", sink.text.c_str());
  if (t.find("country") == std::string::npos) return fail("words missing");
  for (auto& [a, b] : sink.times) {
    std::printf("  [%lld, %lld]\n", static_cast<long long>(a), static_cast<long long>(b));
    if (a < 19000 || b > 32000 || b < a) return fail("times not on the original timeline");
  }
  return 0;
}

int stt_v1() {
  if (!have(true)) return kSkip;
  vv_stt_params p = vv_stt_default_params();
  p.struct_size = VV_STT_PARAMS_V1_SIZE;  // older caller: no VAD fields
  p.vad_model_path = "/must/not/be/read";
  Sink sink;
  if (int rc = transcribe(g_jfk, p, &sink)) return rc;
  if (sink.text.empty()) return fail("v1 layout transcription");
  return 0;
}

// Host bench (not a ctest): jfk.wav with 4 s pauses x 10 (~55 % speech,
// like a meeting with gaps); prints STT wall time and text without / with
// VAD. AUD-03 AC1 is decided on the QA-02 corpus on devices; this is the
// host sanity number recorded in ADR-AUD-03.
int bench() {
  if (!have(true)) return kSkip;
  const std::vector<float> speech = jfk();
  std::vector<float> pcm;
  for (int i = 0; i < 10; ++i) {
    pcm.insert(pcm.end(), speech.begin(), speech.end());
    pcm.insert(pcm.end(), 16000 * 4 * (1 + i % 3), 0.0f);  // 4/8/12 s gaps
  }
  const std::string wav = write_wav("bench", pcm);
  for (int run = 0; run < 8; ++run) {
    const int with_vad = (run + 1) % 2;
    vv_stt_params p = vv_stt_default_params();
    if (with_vad) p.vad_model_path = g_vad.c_str();
    Sink sink;
    const auto t0 = std::chrono::steady_clock::now();
    if (int rc = transcribe(wav, p, &sink)) return rc;
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::steady_clock::now() - t0)
                        .count();
    std::printf("bench %s VAD: %lld ms for %zu ms audio, %zu segments\n", with_vad ? "with" : "without",
                static_cast<long long>(ms), pcm.size() / 16, sink.times.size());
  }
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
  const std::string mode = argc > 1 ? argv[1] : "args";
  if (mode == "args") return args();
  if (mode == "segments") return segments();
  if (mode == "stream") return stream();
  if (mode == "stt_silence") return stt_silence();
  if (mode == "stt_mapped") return stt_mapped();
  if (mode == "stt_v1") return stt_v1();
  if (mode == "bench") return bench();
  std::fprintf(stderr, "unknown mode %s\n", mode.c_str());
  return 2;
}
