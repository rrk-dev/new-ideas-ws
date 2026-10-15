// SEC-08 fuzz target: GGUF header/metadata parsing used when a model file is
// loaded (ggml gguf.h, pinned with native/llama.cpp). Tensor data is never
// allocated (no_alloc) so the target stresses the parser only. Build with
// native/fuzz/build_fuzz.sh gguf (needs clang with libFuzzer and the submodule).
#include <cstddef>
#include <cstdint>

#include "gguf.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  gguf_init_params params = {/*no_alloc=*/true, /*ctx=*/nullptr};
  gguf_context* ctx = gguf_init_from_buffer(data, size, params);
  if (ctx) {
    const int64_t n = gguf_get_n_kv(ctx);
    for (int64_t i = 0; i < n && i < 64; i++) (void)gguf_get_key(ctx, i);
    gguf_free(ctx);
  }
  return 0;
}
