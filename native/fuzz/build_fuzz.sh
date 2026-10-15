#!/usr/bin/env bash
# SEC-08: build and run the native fuzz targets on a desktop host.
#   native/fuzz/build_fuzz.sh wav [rounds]     standalone mutation run (any clang/g++)
#   native/fuzz/build_fuzz.sh libfuzzer wav|gguf [seconds]
#                                              coverage-guided run (clang with libFuzzer,
#                                              e.g. Linux or Homebrew LLVM; not Apple clang)
# gguf additionally needs the llama.cpp submodule and a host ggml build
# (native/build.sh host, static libggml*.a under native/build/host). Not run in
# the authoring environment (no libFuzzer); the wav target is. Output goes to native/build/fuzz (gitignored).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../build/fuzz"
mkdir -p "$OUT"
CXX="${CXX:-c++}"
SAN="-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1 -std=c++17"
MODE="${1:?wav|libfuzzer}"
case "$MODE" in
  wav)
    "$CXX" $SAN "$HERE/fuzz_wav.cpp" "$HERE/fuzz_driver.cpp" -o "$OUT/fuzz_wav_standalone"
    python3 "$HERE/gen_seeds.py"
    UBSAN_OPTIONS=halt_on_error=1 "$OUT/fuzz_wav_standalone" "$HERE/corpus/wav" --rounds "${2:-200}";;
  libfuzzer)
    TARGET="${2:?wav|gguf}"; SECS="${3:-60}"
    EXTRA=()
    if [ "$TARGET" = gguf ]; then
      GGML="$HERE/../llama.cpp/ggml"
      [ -d "$GGML" ] || { echo "llama.cpp submodule missing" >&2; exit 2; }
      LIBS=$(find "$HERE/../build/host" -name 'libggml*.a' 2>/dev/null | tr '\n' ' ')
      [ -n "$LIBS" ] || { echo "run native/build.sh host first (needs libggml*.a)" >&2; exit 2; }
      # shellcheck disable=SC2206
      EXTRA=(-I"$GGML/include" $LIBS)
    fi
    "$CXX" $SAN -fsanitize=fuzzer "${EXTRA[@]}" "$HERE/fuzz_$TARGET.cpp" -o "$OUT/fuzz_$TARGET"
    mkdir -p "$OUT/corpus-$TARGET"
    "$OUT/fuzz_$TARGET" "$OUT/corpus-$TARGET" "$HERE/corpus/$TARGET" -max_total_time="$SECS";;
  *) echo "usage: $0 wav|libfuzzer ..." >&2; exit 2;;
esac
