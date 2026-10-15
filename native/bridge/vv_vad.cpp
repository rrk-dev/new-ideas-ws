// [AUD-03] whisper.cpp Silero VAD behind the vv_vad_* C ABI (see vv_vad.h).
#include "vv_vad.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <vector>

#include "vv_bridge.h"
#include "vv_wav.h"
#include "whisper.h"

struct vv_vad {
  whisper_vad_context* ctx = nullptr;
  vv_vad_params params{};
  std::vector<float> pending;  // streaming: samples of the incomplete window
  std::mutex mu;
  std::string last_error;
};

namespace {

// Silero window at 16 kHz (whisper.cpp v1.9.5 whisper_vad_context::n_window).
constexpr size_t kWindow = 512;

thread_local std::string t_create_error;

void set_error(vv_vad* h, const char* msg) {
  if (h) {
    h->last_error = msg;
  } else {
    t_create_error = msg;
  }
}

whisper_vad_params to_whisper(const vv_vad_params& p) {
  whisper_vad_params w = whisper_vad_default_params();
  w.threshold = p.threshold;
  w.min_speech_duration_ms = p.min_speech_ms;
  w.min_silence_duration_ms = p.min_silence_ms;
  w.speech_pad_ms = p.speech_pad_ms;
  if (p.max_speech_s > 0) w.max_speech_duration_s = p.max_speech_s;
  return w;
}

}  // namespace

extern "C" {

vv_vad_params vv_vad_default_params(void) {
  vv_vad_params p;
  std::memset(&p, 0, sizeof(p));
  p.struct_size = sizeof(p);
  p.threshold = 0.5f;
  p.min_speech_ms = 250;
  p.min_silence_ms = 500;
  p.speech_pad_ms = 200;
  p.max_speech_s = 0.0f;
  p.n_threads = 1;
  return p;
}

int32_t vv_vad_create(const char* model_path, const vv_vad_params* params, vv_vad** out) {
  if (out) *out = nullptr;
  if (!model_path || !*model_path || !out ||
      (params && params->struct_size < sizeof(vv_vad_params))) {
    set_error(nullptr, "invalid argument");
    return VV_E_INVALID_ARG;
  }
  // A GGML_BACKEND_DL build registers no CPU device until vv_backends_load
  // runs, and VAD can be the first ggml user of a process (pipeline worker,
  // recording isolate): whisper_vad_init would abort on GGML_ASSERT(device).
  // Registering the CPU module is idempotent (no-op in static builds).
  // Integration wave 3 (AUD-03 x STT-02 DL backends).
  if (vv_backends_load(nullptr, 0) != VV_OK) {
    set_error(nullptr, "no CPU backend");
    return VV_E_BACKEND;
  }
  try {
    auto* h = new vv_vad();
    h->params = params ? *params : vv_vad_default_params();
    whisper_vad_context_params cp = whisper_vad_default_context_params();
    cp.n_threads = std::max(h->params.n_threads, 1);
    cp.use_gpu = false;  // tiny model: CPU only, also in the background
    h->ctx = whisper_vad_init_from_file_with_params(model_path, cp);
    if (!h->ctx) {
      delete h;
      set_error(nullptr, "VAD model could not be loaded");
      return VV_E_MODEL_LOAD;
    }
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

int32_t vv_vad_segments(vv_vad* h, const vv_audio_range* ranges, size_t n, char** out_json) {
  if (out_json) *out_json = nullptr;
  if (!h || !ranges || n == 0 || !out_json) {
    if (h) {
      std::lock_guard<std::mutex> lock(h->mu);
      set_error(h, "invalid argument");
    }
    return VV_E_INVALID_ARG;
  }
  std::lock_guard<std::mutex> lock(h->mu);
  try {
    std::vector<float> pcm;
    for (size_t i = 0; i < n; ++i) {
      if (!ranges[i].path || !*ranges[i].path) {
        set_error(h, "invalid argument");
        return VV_E_INVALID_ARG;
      }
      const vv::WavStatus st =
          vv::wav_read_range(ranges[i].path, ranges[i].start_ms, ranges[i].end_ms, &pcm);
      if (st != vv::WavStatus::ok) {
        set_error(h, st == vv::WavStatus::io ? "audio file not readable"
                                              : "audio must be 16 kHz PCM16 WAV");
        return st == vv::WavStatus::io ? VV_E_IO : VV_E_INVALID_ARG;
      }
    }
    h->pending.clear();
    std::string json = "[";
    if (!pcm.empty()) {
      whisper_vad_segments* segs = whisper_vad_segments_from_samples(
          h->ctx, to_whisper(h->params), pcm.data(), static_cast<int>(pcm.size()));
      if (!segs) {
        set_error(h, "VAD failed");
        return VV_E_INTERNAL;
      }
      const int count = whisper_vad_segments_n_segments(segs);
      const int64_t total_ms = static_cast<int64_t>(pcm.size()) * 1000 / vv::kWavSampleRate;
      char buf[64];
      for (int i = 0; i < count; ++i) {
        // Centiseconds -> ms, clamped to the input.
        int64_t s = static_cast<int64_t>(whisper_vad_segments_get_segment_t0(segs, i) * 10.0f);
        int64_t e = static_cast<int64_t>(whisper_vad_segments_get_segment_t1(segs, i) * 10.0f);
        s = std::clamp<int64_t>(s, 0, total_ms);
        e = std::clamp<int64_t>(e, s, total_ms);
        std::snprintf(buf, sizeof(buf), "%s{\"start_ms\":%lld,\"end_ms\":%lld}", i ? "," : "",
                      static_cast<long long>(s), static_cast<long long>(e));
        json += buf;
      }
      whisper_vad_free_segments(segs);
    }
    json += "]";
    char* out = static_cast<char*>(std::malloc(json.size() + 1));
    if (!out) throw std::bad_alloc();
    std::memcpy(out, json.c_str(), json.size() + 1);
    *out_json = out;
    return VV_OK;
  } catch (const std::bad_alloc&) {
    set_error(h, "out of memory");
    return VV_E_OOM;
  } catch (...) {
    set_error(h, "internal error");
    return VV_E_INTERNAL;
  }
}

int32_t vv_vad_feed(vv_vad* h, const int16_t* pcm, size_t n, vv_vad_feed_result* out) {
  if (out) {
    out->windows = 0;
    out->speech_windows = 0;
    out->max_prob = -1.0f;
  }
  if (!h || !out || (n > 0 && !pcm)) {
    if (h) {
      std::lock_guard<std::mutex> lock(h->mu);
      set_error(h, "invalid argument");
    }
    return VV_E_INVALID_ARG;
  }
  std::lock_guard<std::mutex> lock(h->mu);
  try {
    h->pending.reserve(h->pending.size() + n);
    for (size_t i = 0; i < n; ++i) h->pending.push_back(pcm[i] / 32768.0f);
    const size_t windows = h->pending.size() / kWindow;
    if (windows == 0) return VV_OK;
    const size_t used = windows * kWindow;
    if (!whisper_vad_detect_speech_no_reset(h->ctx, h->pending.data(), static_cast<int>(used))) {
      set_error(h, "VAD failed");
      return VV_E_INTERNAL;
    }
    h->pending.erase(h->pending.begin(), h->pending.begin() + static_cast<std::ptrdiff_t>(used));
    const int np = whisper_vad_n_probs(h->ctx);
    const float* probs = whisper_vad_probs(h->ctx);
    int32_t speech = 0;
    float max_p = -1.0f;
    for (int i = 0; i < np; ++i) {
      max_p = std::max(max_p, probs[i]);
      if (probs[i] >= h->params.threshold) ++speech;
    }
    out->windows = np;
    out->speech_windows = speech;
    out->max_prob = max_p;
    return VV_OK;
  } catch (const std::bad_alloc&) {
    set_error(h, "out of memory");
    return VV_E_OOM;
  } catch (...) {
    set_error(h, "internal error");
    return VV_E_INTERNAL;
  }
}

void vv_vad_reset(vv_vad* h) {
  if (!h) return;
  std::lock_guard<std::mutex> lock(h->mu);
  h->pending.clear();
  whisper_vad_reset_state(h->ctx);
}

void vv_vad_destroy(vv_vad* h) {
  if (!h) return;
  {
    std::lock_guard<std::mutex> lock(h->mu);
    if (h->ctx) whisper_vad_free(h->ctx);
    h->ctx = nullptr;
  }
  delete h;
}

const char* vv_vad_last_error(vv_vad* h) {
  if (!h) return t_create_error.c_str();
  return h->last_error.c_str();
}

}  // extern "C"
