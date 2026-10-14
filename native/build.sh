#!/usr/bin/env bash
# Build the native bridge (whisper.cpp + llama.cpp + one ggml -> vv_native).
#
#   native/build.sh host      macOS/Linux dylib/so + ctest (smoke + exports)
#   native/build.sh android   libvv_native.so for arm64-v8a (needs Android NDK r28+)
#   native/build.sh ios       vv_native.xcframework: device + simulator (needs Xcode)
#   native/build.sh macos     arm64 vv_native.framework for the desktop app (needs Xcode Metal)
#   native/build.sh all       android + ios + macos + host (whatever the OS supports)
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
MACOS_MIN_OS="${MACOS_MIN_OS:-13.0}"      # desktop minimum (FND-09 / FND-10)
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
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="")
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

# macOS desktop (FND-10). Same superproject as host/iOS: llama.cpp's ggml once,
# whisper + llama static, Metal embedded. Output is a framework (not the host
# dylib) so the Flutter plugin can vendor it into Contents/Frameworks.
require_macos_sdk() {
  local err
  if ! err="$(xcrun --show-sdk-path --sdk macosx 2>&1)"; then
    echo "error: macOS SDK is not usable; native/build.sh macos needs Xcode Metal." >&2
    printf '%s\n' "$err" >&2
    if printf '%s' "$err" | grep -qi 'license'; then
      echo "error: the Xcode license is not accepted. Run 'sudo xcodebuild -license' in a Terminal. This script does not run sudo." >&2
    fi
    exit 2
  fi
}

build_macos() {
  need cmake "brew install cmake"
  need ninja "brew install ninja"
  check_submodules
  require_macos_sdk
  local arch
  arch="$(uname -m)"
  if [ "$arch" != "arm64" ]; then
    echo "error: native/build.sh macos builds arm64 only (this host is $arch)" >&2
    exit 2
  fi
  local dir="$OUT/macos"
  # Flags match the FND-06 host/iOS Metal build (one ggml, no backend DL).
  # Option names verified at whisper.cpp v1.9.5 / llama.cpp v0.6.0.
  cmake -S "$NATIVE" -B "$dir" -G Ninja "${COMMON[@]}" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN_OS" \
    -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_METAL_TARGET_OS=macos \
    -DGGML_OPENMP=OFF -DGGML_NATIVE=OFF \
    -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=Apple \
    -DVV_GGML_BACKEND_DL=OFF \
    -DVV_MACOS_FRAMEWORK=ON
  cmake --build "$dir" -j "$JOBS"
  ctest --test-dir "$dir" --output-on-failure
  local bin="$dir/vv_native.framework/vv_native"
  if [ ! -f "$bin" ]; then
    bin="$dir/vv_native.framework/Versions/A/vv_native"
  fi
  if [ ! -f "$bin" ]; then
    echo "error: framework binary not found under $dir" >&2
    exit 1
  fi
  local info
  info="$(file "$bin")"
  case "$info" in
    *arm64*) ;;
    *) echo "error: $bin is not arm64 ($info)" >&2; exit 1 ;;
  esac
  if compgen -G "$dir/libggml*" >/dev/null; then
    echo "error: $dir contains extra ggml libraries; refusing a second ggml" >&2
    exit 1
  fi
  if ! otool -L "$bin" | grep -q 'Metal.framework'; then
    echo "error: $bin is not linked to Metal.framework" >&2
    exit 1
  fi
  local pod="$NATIVE/../packages/vv_native/macos/Frameworks"
  rm -rf "$pod"
  mkdir -p "$pod"
  cp -R "$dir/vv_native.framework" "$pod/"
  echo "macos: $bin $(size_of "$bin") bytes"
}

# Order: arguments (exit 64) -> toolchain (exit 2) -> submodules (exit 2), so a
# checkout without submodules (CI task-gate) still gets the precise error.
case "${1:-}" in
  host|android|ios|macos|all) ;;
  *) echo "usage: $0 {host|android|ios|macos|all}" >&2; exit 64 ;;
esac
case "$1" in
  host) build_host ;;
  android) build_android ;;
  ios) build_ios ;;
  macos) build_macos ;;
  all)
    build_host
    (find_ndk) >/dev/null 2>&1 && build_android || echo "skip android: no NDK"
    have_xcode && build_ios || echo "skip ios: no Xcode"
    if [ "$(uname -s)" = Darwin ]; then
      if xcrun --show-sdk-path --sdk macosx >/dev/null 2>&1; then
        build_macos
      else
        echo "skip macos: Xcode license not accepted or macOS SDK unavailable"
      fi
    fi ;;
esac
