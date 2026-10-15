#!/usr/bin/env bash
# Build the native bridge (whisper.cpp + llama.cpp + one ggml -> vv_native).
#
#   native/build.sh host      macOS/Linux dylib/so + ctest (smoke + exports)
#   native/build.sh android   libvv_native.so for arm64-v8a (needs Android NDK r28+)
#   native/build.sh ios       vv_native.xcframework: device + simulator (needs Xcode)
#   native/build.sh all       android + ios + host (whatever the OS supports)
#   VV_WHISPER_COREML=ON native/build.sh ios   adds the whisper Core ML encoder (STT-01)
#
# From a clean checkout:
#   git submodule update --init --recursive && native/build.sh <target>
# Output lands in native/build/<target>/ (gitignored); sizes are printed so they
# can be recorded in native/VERSIONS.md.
set -euo pipefail

NATIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$NATIVE/build"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
IOS_MIN_OS="${IOS_MIN_OS:-16.0}"          # app minimum; llama.cpp script uses 16.4 (ADR-FND-06)
ANDROID_API="${ANDROID_API:-26}"
ANDROID_NDK_MIN_MAJOR=28

COMMON=(-DCMAKE_BUILD_TYPE=Release -Wno-deprecated -Wno-dev)
if command -v ccache >/dev/null 2>&1; then
  COMMON+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found ($2)" >&2; exit 2; }; }

check_submodules() {
  for d in whisper.cpp llama.cpp; do
    [ -f "$NATIVE/$d/CMakeLists.txt" ] || {
      echo "error: native/$d is empty. Run: git submodule update --init --recursive" >&2; exit 2; }
  done
}

have_xcode() { xcodebuild -version >/dev/null 2>&1; }

size_of() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }

build_host() {
  need cmake "brew install cmake"; need ninja "brew install ninja"
  check_submodules
  cmake -S "$NATIVE" -B "$OUT/host" -G Ninja "${COMMON[@]}"
  cmake --build "$OUT/host" -j "$JOBS"
  ctest --test-dir "$OUT/host" --output-on-failure
  local lib; lib="$(ls "$OUT"/host/libvv_native.* | head -1)"
  echo "host: $lib $(size_of "$lib") bytes"
}

find_ndk() {
  local ndk="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
  if [ -z "$ndk" ]; then
    local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
    ndk="$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
  fi
  [ -n "$ndk" ] && [ -f "$ndk/build/cmake/android.toolchain.cmake" ] || {
    echo "error: Android NDK r${ANDROID_NDK_MIN_MAJOR}+ not found (set ANDROID_NDK_HOME)" >&2; exit 2; }
  local major; major="$(basename "$ndk" | cut -d. -f1)"
  case "$major" in ''|*[!0-9]*) ;; *)
    [ "$major" -ge "$ANDROID_NDK_MIN_MAJOR" ] || {
      echo "error: NDK $(basename "$ndk") < r$ANDROID_NDK_MIN_MAJOR (16 KB page alignment)" >&2; exit 2; } ;;
  esac
  echo "$ndk"
}

build_android() {
  # Toolchain first (clear NDK error even without submodules), then sources.
  local ndk; ndk="$(find_ndk)"
  need cmake "brew install cmake"; need ninja "brew install ninja"
  check_submodules
  local dir="$OUT/android/arm64-v8a"
  cmake -S "$NATIVE" -B "$dir" -G Ninja "${COMMON[@]}" \
    -DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$ANDROID_API" \
    -DANDROID_STL="$( [ "${VV_GGML_BACKEND_DL:-OFF}" = ON ] && echo c++_shared || echo c++_static )" \
    -DGGML_OPENMP=OFF -DGGML_LLAMAFILE=OFF -DGGML_NATIVE=OFF \
    ${VV_ANDROID_CPU_ARCH:+-DVV_ANDROID_CPU_ARCH="$VV_ANDROID_CPU_ARCH"} \
    -DVV_GGML_BACKEND_DL="${VV_GGML_BACKEND_DL:-OFF}" \
    -DVV_GGML_VULKAN="${VV_GGML_VULKAN:-OFF}" -DVV_GGML_OPENCL="${VV_GGML_OPENCL:-OFF}"  # STT-02
  cmake --build "$dir" -j "$JOBS"
  local so="$dir/libvv_native.so"
  local tool="$ndk/toolchains/llvm/prebuilt/$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)/bin"
  "$tool/llvm-strip" --strip-unneeded -o "$dir/libvv_native.stripped.so" "$so"
  # 16 KB alignment: every LOAD segment must have align 2**14.
  if "$tool/llvm-objdump" -p "$so" | grep LOAD | grep -v '2\*\*14' >/dev/null; then
    echo "error: $so has LOAD segments not aligned to 16 KB" >&2; exit 1
  fi
  echo "android: $so unstripped $(size_of "$so") bytes, stripped $(size_of "$dir/libvv_native.stripped.so") bytes (16 KB aligned)"
}

build_ios() {
  have_xcode || { echo "error: full Xcode required (xcode-select -s /Applications/Xcode.app)" >&2; exit 2; }
  need cmake "brew install cmake"
  check_submodules
  local args=(-G Xcode "${COMMON[@]}"
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_MIN_OS"
    -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_METAL_TARGET_OS=ios
    -DGGML_OPENMP=OFF -DGGML_NATIVE=OFF -DGGML_BLAS_DEFAULT=ON
    -DVV_WHISPER_COREML="${VV_WHISPER_COREML:-OFF}"   # STT-01: Core ML encoder (ADR-STT-01)
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=""
    # REL-03: strip local symbols from the framework binary at build time (it is
    # a prebuilt xcframework, so the app's archive strip never touches it) and
    # keep a private dSYM for symbolication (REL-02). non-global keeps the
    # exported vv_* entry points Dart looks up.
    -DCMAKE_XCODE_ATTRIBUTE_DEPLOYMENT_POSTPROCESSING=YES
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=YES
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_STYLE=non-global
    -DCMAKE_XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING=YES
    -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT=dwarf-with-dsym)
  local dev="$OUT/ios/device" sim="$OUT/ios/simulator"
  cmake -S "$NATIVE" -B "$dev" "${args[@]}" -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphoneos
  cmake --build "$dev" --config Release -j "$JOBS" --target vv_native
  cmake -S "$NATIVE" -B "$sim" "${args[@]}" -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphonesimulator
  cmake --build "$sim" --config Release -j "$JOBS" --target vv_native
  rm -rf "$OUT/ios/vv_native.xcframework"
  xcodebuild -create-xcframework \
    -framework "$dev/Release-iphoneos/vv_native.framework" \
    -framework "$sim/Release-iphonesimulator/vv_native.framework" \
    -output "$OUT/ios/vv_native.xcframework"
  # The CocoaPods plugin vends the xcframework from packages/vv_native/ios/Frameworks.
  local pod="$NATIVE/../packages/vv_native/ios/Frameworks"
  rm -rf "$pod"; mkdir -p "$pod"
  cp -R "$OUT/ios/vv_native.xcframework" "$pod/"
  echo "ios: device slice $(size_of "$dev/Release-iphoneos/vv_native.framework/vv_native") bytes;" \
       "simulator slice $(size_of "$sim/Release-iphonesimulator/vv_native.framework/vv_native") bytes"
}

# Order: arguments (exit 64) -> toolchain (exit 2) -> submodules (exit 2), so a
# checkout without submodules (CI task-gate) still gets the precise error.
case "${1:-}" in
  host|android|ios|all) ;;
  *) echo "usage: $0 {host|android|ios|all}" >&2; exit 64 ;;
esac
case "$1" in
  host) build_host ;;
  android) build_android ;;
  ios) build_ios ;;
  all)
    build_host
    (find_ndk) >/dev/null 2>&1 && build_android || echo "skip android: no NDK"
    have_xcode && build_ios || echo "skip ios: no Xcode" ;;
esac
