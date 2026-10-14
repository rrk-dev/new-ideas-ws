#!/usr/bin/env bash
# Host STT backend bench (STT-01/STT-02, vv-benchmark-eval): whisper.cpp RTF for
# Metal-only, CPU-only and (Apple) Core ML encoder builds of the same pins.
#
#   tools/bench/stt_host_bench.sh [--model FILE] [--wav FILE] [--seconds 60] [--runs 3]
#
# Defaults: ggml-base.en-q8_0.bin + its Core ML encoder from $VV_BENCH_MODELS_DIR
# (default ~/.cache/vaultvoice/bench — outside the repo; never commit models) and
# jfk.wav from tools/ci/fetch_test_models.sh, tiled to --seconds of audio.
# Builds native/build/host (Metal-only) and native/build/host-coreml
# (VV_WHISPER_COREML=ON) if missing. Prints one JSON line per configuration;
# the device runner for the acceptance numbers is the on-device bench (STT-03).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCH="${VV_BENCH_MODELS_DIR:-$HOME/.cache/vaultvoice/bench}"
TEST="${VV_TEST_MODELS_DIR:-$HOME/.cache/vaultvoice/test-models}"
MODEL="$BENCH/ggml-base.en-q8_0.bin"
WAV="$TEST/jfk.wav"
SECONDS_AUDIO=60
RUNS=3
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --wav) WAV="$2"; shift 2 ;;
    --seconds) SECONDS_AUDIO="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done
[ -f "$MODEL" ] || { echo "missing model $MODEL" >&2; exit 2; }
[ -f "$WAV" ] || { echo "missing $WAV (run tools/ci/fetch_test_models.sh jfk.wav)" >&2; exit 2; }

build() {  # dir, extra cmake args...
  local dir="$1"; shift
  if [ ! -x "$ROOT/native/build/$dir/stt_backends" ]; then
    cmake -S "$ROOT/native" -B "$ROOT/native/build/$dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -Wno-dev "$@" >/dev/null
  fi
  cmake --build "$ROOT/native/build/$dir" --target stt_backends -j >/dev/null
}

run() {  # dir, label, gpu
  "$ROOT/native/build/$1/stt_backends" bench --model "$MODEL" --wav "$WAV" \
    --seconds "$SECONDS_AUDIO" --runs "$RUNS" --gpu "$3" --label "$2"
}

echo "# $(uname -sm) $(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)" \
     "whisper.cpp $(git -C "$ROOT/native/whisper.cpp" describe --tags 2>/dev/null || echo '?')" \
     "model sha256 $(shasum -a 256 "$MODEL" | cut -c1-16)"
build host
run host metal 1
run host cpu 0
if [ "$(uname -s)" = Darwin ]; then
  build host-coreml -DVV_WHISPER_COREML=ON
  # First Core ML run includes the one-time ANE compile when the cache is cold.
  run host-coreml coreml+metal 1
  run host-coreml coreml+cpu 0
fi
