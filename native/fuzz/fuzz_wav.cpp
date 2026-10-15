// SEC-08 fuzz target: the bridge's RIFF/WAVE header parser (native/bridge/vv_wav.h).
// libFuzzer entry point; also built with fuzz_driver.cpp as a standalone mutation
// runner where libFuzzer is unavailable (Apple clang). Invariants checked:
// no crash/UB, and an accepted header never points outside the input.
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

#include "../bridge/vv_wav.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size == 0) return 0;
  FILE* f = fmemopen(const_cast<uint8_t*>(data), size, "rb");
  if (!f) return 0;
  vv::WavInfo info;
  if (vv::detail::parse(f, &info) == vv::WavStatus::ok) {
    if (info.data_offset + info.data_bytes > size) std::abort();
    if (info.channels < 1 || info.channels > 8 || info.bits != 16 ||
        info.sample_rate != 16000)
      std::abort();
  }
  std::fclose(f);
  return 0;
}
