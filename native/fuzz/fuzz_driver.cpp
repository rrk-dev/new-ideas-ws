// Standalone replacement for libFuzzer's main(): replays every seed file and a
// deterministic set of mutations (bit flips, byte overwrites, truncation, length
// field extremes) through LLVMFuzzerTestOneInput. Use with ASan/UBSan. Not a
// coverage-guided fuzzer; it gives a CI regression run where libFuzzer is absent.
// Usage: fuzz_driver <seed-dir-or-file>... [--rounds N]
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <random>
#include <string>
#include <vector>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size);

namespace fs = std::filesystem;

static std::vector<uint8_t> read_file(const fs::path& p) {
  std::ifstream in(p, std::ios::binary);
  return {std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>()};
}

static void run(const std::vector<uint8_t>& v) {
  static const uint8_t empty = 0;
  LLVMFuzzerTestOneInput(v.empty() ? &empty : v.data(), v.size());
}

int main(int argc, char** argv) {
  int rounds = 200;
  std::vector<fs::path> seeds;
  for (int i = 1; i < argc; i++) {
    if (!std::strcmp(argv[i], "--rounds") && i + 1 < argc) {
      rounds = std::atoi(argv[++i]);
    } else if (fs::is_directory(argv[i])) {
      for (auto& e : fs::directory_iterator(argv[i]))
        if (e.is_regular_file()) seeds.push_back(e.path());
    } else {
      seeds.push_back(argv[i]);
    }
  }
  std::mt19937_64 rng(0x5EC08);
  size_t executions = 0;
  for (auto& s : seeds) {
    const auto base = read_file(s);
    run(base);
    executions++;
    for (int r = 0; r < rounds; r++) {
      auto v = base;
      switch (rng() % 5) {
        case 0:
          if (!v.empty()) v[rng() % v.size()] ^= uint8_t(1u << (rng() % 8));
          break;
        case 1:
          if (!v.empty()) v[rng() % v.size()] = uint8_t(rng());
          break;
        case 2:
          if (!v.empty()) v.resize(rng() % v.size());
          break;
        case 3:  // 0xFF run: oversize lengths and counts
          if (v.size() > 4) {
            const size_t at = rng() % (v.size() - 4);
            std::memset(&v[at], 0xFF, 4);
          }
          break;
        default:  // append junk
          for (int k = 0; k < 16; k++) v.push_back(uint8_t(rng()));
      }
      run(v);
      executions++;
    }
  }
  std::printf("fuzz_driver: %zu executions, %zu seeds, no crash\n", executions,
              seeds.size());
  return 0;
}
