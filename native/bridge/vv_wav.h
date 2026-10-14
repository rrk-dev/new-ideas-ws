// Internal (not part of the C ABI): minimal RIFF/WAVE reader for the 16 kHz
// PCM16 chunk files the recorder writes (vv-audio-capture). Header-only so the
// bridge and host test/bench tools share one implementation.
//
// Supports: PCM (format 1) or WAVE_FORMAT_EXTENSIBLE with PCM sub-format,
// 16-bit, 16000 Hz, 1..8 channels (downmixed to mono). Anything else is
// rejected — resampling belongs to import (AUD-xx), not the STT engine.
#ifndef VV_WAV_H
#define VV_WAV_H

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

namespace vv {

constexpr int kWavSampleRate = 16000;

enum class WavStatus { ok, io, format };

struct WavInfo {
  uint16_t channels = 0;
  uint32_t sample_rate = 0;
  uint16_t bits = 0;
  uint64_t data_offset = 0;  // byte offset of the first sample
  uint64_t data_bytes = 0;   // bytes of sample data (clamped to the file)
  uint64_t frames() const { return channels ? data_bytes / (2ull * channels) : 0; }
  int64_t duration_ms() const {
    return static_cast<int64_t>(frames() * 1000 / (sample_rate ? sample_rate : 1));
  }
};

namespace detail {
inline uint32_t le32(const uint8_t* p) {
  return uint32_t(p[0]) | uint32_t(p[1]) << 8 | uint32_t(p[2]) << 16 | uint32_t(p[3]) << 24;
}
inline uint16_t le16(const uint8_t* p) { return uint16_t(p[0] | p[1] << 8); }

struct File {
  explicit File(const char* path) : f(std::fopen(path, "rb")) {}
  ~File() {
    if (f) std::fclose(f);
  }
  File(const File&) = delete;
  File& operator=(const File&) = delete;
  FILE* f;
};

inline bool seek(FILE* f, uint64_t off) {
#if defined(_WIN32)
  return _fseeki64(f, static_cast<long long>(off), SEEK_SET) == 0;
#else
  return fseeko(f, static_cast<off_t>(off), SEEK_SET) == 0;
#endif
}

inline uint64_t file_size(FILE* f) {
#if defined(_WIN32)
  _fseeki64(f, 0, SEEK_END);
  return static_cast<uint64_t>(_ftelli64(f));
#else
  fseeko(f, 0, SEEK_END);
  return static_cast<uint64_t>(ftello(f));
#endif
}

inline WavStatus parse(FILE* f, WavInfo* out) {
  uint8_t hdr[12];
  if (std::fread(hdr, 1, 12, f) != 12) return WavStatus::format;
  if (std::memcmp(hdr, "RIFF", 4) != 0 || std::memcmp(hdr + 8, "WAVE", 4) != 0)
    return WavStatus::format;
  const uint64_t size = file_size(f);
  uint64_t pos = 12;
  bool have_fmt = false;
  WavInfo info;
  while (pos + 8 <= size) {
    if (!seek(f, pos)) return WavStatus::io;
    uint8_t ch[8];
    if (std::fread(ch, 1, 8, f) != 8) return WavStatus::format;
    const uint32_t len = le32(ch + 4);
    const uint64_t body = pos + 8;
    if (std::memcmp(ch, "fmt ", 4) == 0) {
      if (len < 16) return WavStatus::format;
      uint8_t fmt[40] = {0};
      const size_t n = len < sizeof(fmt) ? len : sizeof(fmt);
      if (std::fread(fmt, 1, n, f) != n) return WavStatus::format;
      uint16_t tag = le16(fmt);
      if (tag == 0xFFFE && n >= 26) tag = le16(fmt + 24);  // EXTENSIBLE sub-format GUID
      if (tag != 1) return WavStatus::format;
      info.channels = le16(fmt + 2);
      info.sample_rate = le32(fmt + 4);
      info.bits = le16(fmt + 14);
      have_fmt = true;
    } else if (std::memcmp(ch, "data", 4) == 0) {
      if (!have_fmt) return WavStatus::format;
      info.data_offset = body;
      // Crash-recovered chunks may carry a stale/0xFFFFFFFF length: clamp.
      const uint64_t avail = size - body;
      info.data_bytes = len > avail ? avail : len;
      if (info.channels < 1 || info.channels > 8 || info.bits != 16 ||
          info.sample_rate != static_cast<uint32_t>(kWavSampleRate))
        return WavStatus::format;
      *out = info;
      return WavStatus::ok;
    }
    pos = body + len + (len & 1u);  // chunks are word aligned
  }
  return WavStatus::format;
}
}  // namespace detail

inline WavStatus wav_info(const char* path, WavInfo* out) {
  detail::File file(path);
  if (!file.f) return WavStatus::io;
  return detail::parse(file.f, out);
}

// Appends mono float samples (x / 32768) of [start_ms, end_ms) to `pcm`.
// end_ms < 0 means "to the end of the file". Ranges are clamped to the file.
inline WavStatus wav_read_range(const char* path, int64_t start_ms, int64_t end_ms,
                                std::vector<float>* pcm) {
  detail::File file(path);
  if (!file.f) return WavStatus::io;
  WavInfo info;
  const WavStatus st = detail::parse(file.f, &info);
  if (st != WavStatus::ok) return st;
  const uint64_t frames = info.frames();
  auto to_frame = [&](int64_t ms) -> uint64_t {
    if (ms <= 0) return 0;
    const uint64_t fr = static_cast<uint64_t>(ms) * info.sample_rate / 1000;
    return fr > frames ? frames : fr;
  };
  const uint64_t first = to_frame(start_ms);
  const uint64_t last = end_ms < 0 ? frames : to_frame(end_ms);
  if (last <= first) return WavStatus::ok;
  const uint16_t chn = info.channels;
  if (!detail::seek(file.f, info.data_offset + first * 2ull * chn)) return WavStatus::io;
  pcm->reserve(pcm->size() + static_cast<size_t>(last - first));
  std::vector<int16_t> buf(4096u * chn);
  uint64_t left = last - first;
  while (left > 0) {
    const size_t want = static_cast<size_t>(left < 4096 ? left : 4096);
    const size_t got = std::fread(buf.data(), 2u * chn, want, file.f);
    if (got == 0) break;  // truncated file: keep what we have
    for (size_t i = 0; i < got; ++i) {
      int32_t acc = 0;
      for (uint16_t c = 0; c < chn; ++c) {
        // WAV is little-endian; all supported targets are too.
        acc += buf[i * chn + c];
      }
      pcm->push_back(static_cast<float>(acc) / (32768.0f * chn));
    }
    left -= got;
  }
  return WavStatus::ok;
}

}  // namespace vv

#endif  // VV_WAV_H
