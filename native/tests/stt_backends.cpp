// [STT-01] [STT-02] whisper.cpp backend checks + speed bench on the host.
//
// Links whisper/ggml directly (test tool only — Dart still talks to vv_bridge.h).
//
//   stt_backends check cpu              CPU-only path (use_gpu=false), keyword check
//   stt_backends check gpu              GPU path (Metal on macOS, embedded shader lib)
//   stt_backends check coreml-fallback  Core ML build without the encoder companion
//   stt_backends bench --model M --wav W [--seconds 60] [--runs 3] [--gpu 0|1]
//                      [--threads N] [--beam N] [--label L]
//
// `check` reads ggml-tiny.en.bin + jfk.wav from $VV_TEST_MODELS_DIR
// (tools/ci/fetch_test_models.sh) and exits 77 (ctest SKIP) when they are absent.
// `bench` prints one JSON line per configuration (vv-benchmark-eval reporting).
#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "ggml-backend.h"
#include "vv_wav.h"
#include "whisper.h"

namespace {

constexpr int kSkip = 77;
std::string g_log;

void log_cb(enum ggml_log_level, const char* text, void*) {
  g_log += text;
  if (std::getenv("VV_VERBOSE")) std::fputs(text, stderr);
}

bool has(const std::string& hay, const char* needle) {
  return hay.find(needle) != std::string::npos;
}

std::string lower(std::string s) {
  for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

int fail(const char* what) {
  std::fprintf(stderr, "FAIL: %s\n", what);
  return 1;
}

double now_ms() {
  using namespace std::chrono;
  return duration<double, std::milli>(steady_clock::now().time_since_epoch()).count();
}

struct Run {
  std::string text;
  double load_ms = 0;
  double full_ms = 0;
  bool ok = false;
};

Run transcribe(const std::string& model, const std::vector<float>& pcm, bool gpu,
               int threads, int beam) {
  Run r;
  whisper_context_params cp = whisper_context_default_params();
  cp.use_gpu = gpu;
  const double t0 = now_ms();
  whisper_context* ctx = whisper_init_from_file_with_params(model.c_str(), cp);
  r.load_ms = now_ms() - t0;
  if (!ctx) return r;
  whisper_full_params p = whisper_full_default_params(
      beam > 1 ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY);
  p.n_threads = threads;
  p.language = "en";
  p.translate = false;
  p.no_context = true;
  p.print_progress = false;
  p.print_realtime = false;
  p.print_timestamps = false;
  p.print_special = false;
  p.suppress_nst = true;
  if (beam > 1) p.beam_search.beam_size = beam;
  const double t1 = now_ms();
  const int rc = whisper_full(ctx, p, pcm.data(), static_cast<int>(pcm.size()));
  r.full_ms = now_ms() - t1;
  if (rc == 0) {
    for (int i = 0; i < whisper_full_n_segments(ctx); ++i) r.text += whisper_full_get_segment_text(ctx, i);
    r.ok = true;
  }
  whisper_free(ctx);
  return r;
}

int default_threads() {
  const char* env = std::getenv("VV_THREADS");
  return env ? std::atoi(env) : 4;
}

bool load_jfk(std::string* model, std::vector<float>* pcm) {
  const char* dir = std::getenv("VV_TEST_MODELS_DIR");
  if (!dir || !*dir) return false;
  *model = std::string(dir) + "/ggml-tiny.en.bin";
  const std::string wav = std::string(dir) + "/jfk.wav";
  if (FILE* f = std::fopen(model->c_str(), "rb")) std::fclose(f);
  else return false;  // model not fetched
  return vv::wav_read_range(wav.c_str(), 0, -1, pcm) == vv::WavStatus::ok && !pcm->empty();
}

bool jfk_keywords(const std::string& text) {
  const std::string t = lower(text);
  return has(t, "ask not") && has(t, "country");
}

int check(const std::string& mode) {
  std::string model;
  std::vector<float> pcm;
  if (!load_jfk(&model, &pcm)) {
    std::printf("SKIP: set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)\n");
    return kSkip;
  }
  const std::string sys = whisper_print_system_info();
  if (mode == "cpu") {
    g_log.clear();
    const Run r = transcribe(model, pcm, /*gpu=*/false, default_threads(), 1);
    if (!r.ok) return fail("cpu transcription");
    if (has(g_log, "using MTL") || has(g_log, "using Vulkan") || has(g_log, "using GPU"))
      return fail("use_gpu=false still initialised a GPU backend");
    if (!jfk_keywords(r.text)) return fail("cpu keywords");
    std::printf("cpu OK load=%.0fms full=%.0fms\n", r.load_ms, r.full_ms);
    return 0;
  }
  if (mode == "gpu") {
    size_t gpus = 0;
    for (size_t i = 0; i < ggml_backend_dev_count(); ++i) {
      const auto t = ggml_backend_dev_type(ggml_backend_dev_get(i));
      if (t == GGML_BACKEND_DEVICE_TYPE_GPU || t == GGML_BACKEND_DEVICE_TYPE_IGPU) ++gpus;
    }
    if (gpus == 0) {
      std::printf("SKIP: no GPU backend in this build\n");
      return kSkip;
    }
    g_log.clear();
    const Run r = transcribe(model, pcm, /*gpu=*/true, default_threads(), 1);
    if (!r.ok) return fail("gpu transcription");
#if defined(__APPLE__)
    // Metal with GGML_METAL_EMBED_LIBRARY: no default.metallib next to the
    // binary, so a working MTL backend proves the shader library is embedded.
    if (!has(g_log, "using MTL")) return fail("Metal backend not used");
#endif
    if (!jfk_keywords(r.text)) return fail("gpu keywords");
    std::printf("gpu OK load=%.0fms full=%.0fms\n", r.load_ms, r.full_ms);
    return 0;
  }
  if (mode == "coreml-fallback") {
    if (!has(sys, "COREML = 1")) {
      std::printf("SKIP: not a Core ML build (VV_WHISPER_COREML=OFF)\n");
      return kSkip;
    }
    // ggml-tiny.en-encoder.mlmodelc is never fetched in CI: init must fall
    // back to the ggml encoder instead of failing (WHISPER_COREML_ALLOW_FALLBACK).
    g_log.clear();
    const Run r = transcribe(model, pcm, /*gpu=*/true, default_threads(), 1);
    if (!r.ok) return fail("Core ML build did not fall back without the encoder");
    if (!has(g_log, "failed to load Core ML model")) return fail("expected Core ML load attempt");
    if (!jfk_keywords(r.text)) return fail("fallback keywords");
    std::printf("coreml-fallback OK\n");
    return 0;
  }
  return fail("unknown check mode");
}

int bench(int argc, char** argv) {
  std::string model, wav, label = "host";
  int seconds = 60, runs = 3, gpu = 1, threads = default_threads(), beam = 1;
  for (int i = 2; i + 1 < argc; i += 2) {
    const std::string k = argv[i], v = argv[i + 1];
    if (k == "--model") model = v;
    else if (k == "--wav") wav = v;
    else if (k == "--seconds") seconds = std::atoi(v.c_str());
    else if (k == "--runs") runs = std::atoi(v.c_str());
    else if (k == "--gpu") gpu = std::atoi(v.c_str());
    else if (k == "--threads") threads = std::atoi(v.c_str());
    else if (k == "--beam") beam = std::atoi(v.c_str());
    else if (k == "--label") label = v;
  }
  std::vector<float> src;
  if (model.empty() || wav.empty() || vv::wav_read_range(wav.c_str(), 0, -1, &src) != vv::WavStatus::ok ||
      src.empty())
    return fail("bench needs --model and a 16 kHz PCM16 --wav");
  // Tile the clip to the requested duration (RTF needs a fixed audio length).
  std::vector<float> pcm;
  const size_t want = static_cast<size_t>(seconds) * vv::kWavSampleRate;
  while (pcm.size() < want) pcm.insert(pcm.end(), src.begin(), src.begin() + std::min(src.size(), want - pcm.size()));
  std::vector<double> full, load;
  std::string coreml = "n/a";
  for (int i = 0; i < runs; ++i) {
    g_log.clear();
    const Run r = transcribe(model, pcm, gpu != 0, threads, beam);
    if (!r.ok) return fail("bench transcription");
    full.push_back(r.full_ms);
    load.push_back(r.load_ms);
    if (has(g_log, "Core ML model loaded")) coreml = "loaded";
    else if (has(g_log, "failed to load Core ML")) coreml = "fallback";
  }
  auto stats = [](std::vector<double> v) {
    std::sort(v.begin(), v.end());
    return std::vector<double>{v[v.size() / 2], v.front(), v.back()};
  };
  const auto f = stats(full), l = stats(load);
  std::printf(
      "{\"label\":\"%s\",\"model\":\"%s\",\"audio_s\":%d,\"runs\":%d,\"gpu\":%d,\"threads\":%d,"
      "\"beam\":%d,\"coreml\":\"%s\",\"full_ms_median\":%.0f,\"full_ms_min\":%.0f,"
      "\"full_ms_max\":%.0f,\"load_ms_median\":%.0f,\"load_ms_first\":%.0f,\"rtf\":%.4f}\n",
      label.c_str(), model.substr(model.find_last_of('/') + 1).c_str(), seconds, runs, gpu, threads,
      beam, coreml.c_str(), f[0], f[1], f[2], l[0], load.front(), f[0] / (seconds * 1000.0));
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
  whisper_log_set(log_cb, nullptr);
  if (argc >= 3 && std::strcmp(argv[1], "check") == 0) return check(argv[2]);
  if (argc >= 2 && std::strcmp(argv[1], "bench") == 0) return bench(argc, argv);
  std::fprintf(stderr, "usage: %s check {cpu|gpu|coreml-fallback} | bench --model M --wav W ...\n", argv[0]);
  return 64;
}
