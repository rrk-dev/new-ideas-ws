# VaultVoice native superproject: ONE ggml shared by whisper.cpp and llama.cpp,
# linked statically into one `vv_native` shared library that exports only
# `vv_*` symbols (the C ABI in bridge/vv_bridge.h).
#
# Option names verified at the pinned commits in native/VERSIONS.md
# (whisper.cpp v1.9.5, llama.cpp v0.6.0). Re-check on every bump.
cmake_minimum_required(VERSION 3.22)
project(vv_native C CXX)

# whisper.cpp declares cmake_minimum_required(3.5): without CMP0077 NEW its
# option() calls would silently discard the set() overrides below.
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(BUILD_SHARED_LIBS OFF)            # static ggml/whisper/llama, one shared vv_native
set(GGML_OPENMP OFF)                  # not packageable on Android; see llama.cpp docs/android.md
set(GGML_LLAMAFILE OFF)
set(GGML_BUILD_TESTS OFF)
set(GGML_BUILD_EXAMPLES OFF)

set(LLAMA_BUILD_COMMON OFF)           # llama-common pulls in network (download) code: egress!
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_TOOLS OFF)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_SERVER OFF)
set(LLAMA_BUILD_MTMD OFF)
set(LLAMA_OPENSSL OFF)
set(WHISPER_BUILD_TESTS OFF)
set(WHISPER_BUILD_EXAMPLES OFF)
set(WHISPER_BUILD_SERVER OFF)

# Android CPU baseline. Empty = plain armv8-a NEON (runs on every arm64
# device). A device matrix-approved value such as "armv8.2-a+dotprod" or
# "armv8.2-a+dotprod+i8mm" is forwarded to GGML_CPU_ARM_ARCH — never ship an
# instruction set that can SIGILL on a supported device (ADR-FND-06).
set(VV_ANDROID_CPU_ARCH "" CACHE STRING "ggml CPU arch for Android arm64")
set(GGML_NATIVE OFF)
if(ANDROID AND VV_ANDROID_CPU_ARCH)
  set(GGML_CPU_ARM_ARCH "${VV_ANDROID_CPU_ARCH}")
endif()

# Optional Android GPU backends (LLM-03, ADR-LLM-03). Off by default: every
# device runs the CPU backend until a GPU family passes the device rows and is
# added to the Dart allowlist (kAndroidGpuAllowlist). The bridge never fails
# when a backend finds no usable device — it falls back to CPU.
#  - Vulkan: needs glslc (NDK shader-tools) + Vulkan-Headers matching the pin.
#  - OpenCL (Adreno): needs Khronos OpenCL headers in the NDK sysroot and an
#    NDK-built libOpenCL.so ICD loader (llama.cpp docs/backend/OPENCL.md).
option(VV_ANDROID_VULKAN "Android: build the ggml Vulkan backend" OFF)
option(VV_ANDROID_OPENCL "Android: build the ggml OpenCL (Adreno) backend" OFF)
if(ANDROID)
  set(GGML_VULKAN ${VV_ANDROID_VULKAN})
  set(GGML_OPENCL ${VV_ANDROID_OPENCL})
endif()

# The single ggml. Both projects skip their own copy when a `ggml` target
# exists (`if (NOT TARGET ggml ...)` in llama.cpp/CMakeLists.txt:220 and
# whisper.cpp/CMakeLists.txt:160). Their ggml trees are identical at the pins.
add_subdirectory(llama.cpp/ggml ggml)
add_subdirectory(llama.cpp llama)
add_subdirectory(whisper.cpp whisper)

add_library(vv_native SHARED bridge/vv_bridge.cpp)
# LLM bridge (LLM-02/LLM-03): backend selection, GPU discovery, benchmark.
target_sources(vv_native PRIVATE bridge/vv_llama.cpp bridge/vv_llama_engine.cpp bridge/vv_cpu.c)
target_include_directories(vv_native PUBLIC bridge)
target_link_libraries(vv_native PRIVATE whisper llama ggml)
target_compile_definitions(vv_native PRIVATE VV_BUILDING_LIBRARY=1)

# Export only vv_* from the final library (static deps must not leak ggml_*,
# whisper_*, llama_* — that is what would cause duplicate-symbol clashes).
if(APPLE)
  target_link_options(vv_native PRIVATE
    "-Wl,-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/bridge/vv_exports.txt")
  target_link_options(vv_native PRIVATE -Wl,-dead_strip)
  if(NOT IOS)
    set_target_properties(vv_native PROPERTIES INSTALL_NAME_DIR "@rpath")
  endif()
else()
  target_link_options(vv_native PRIVATE
    "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/bridge/vv_exports.map"
    -Wl,--gc-sections -Wl,--exclude-libs,ALL)
  target_compile_options(vv_native PRIVATE -ffunction-sections -fdata-sections)
endif()

if(IOS)
  # Dynamic framework so Dart can DynamicLibrary.open('vv_native.framework/vv_native').
  set_target_properties(vv_native PROPERTIES
    FRAMEWORK TRUE
    PUBLIC_HEADER bridge/vv_bridge.h
    MACOSX_FRAMEWORK_IDENTIFIER com.vaultvoice.vvnative
    MACOSX_FRAMEWORK_BUNDLE_VERSION 1
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING 0.1.0
    XCODE_ATTRIBUTE_INSTALL_PATH "@rpath"
    XCODE_ATTRIBUTE_SKIP_INSTALL NO)
endif()

if(ANDROID)
  # Google Play 16 KB page-size requirement (also the default on NDK r28+).
  target_link_options(vv_native PRIVATE
    -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384)
  set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")
  set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
endif()

# Host-side tests (native/build.sh host runs ctest). Not built for mobile.
if(NOT ANDROID AND NOT IOS AND PROJECT_IS_TOP_LEVEL)
  enable_testing()
  add_executable(vv_smoke tests/smoke.c)
  target_link_libraries(vv_smoke PRIVATE vv_native)
  add_test(NAME vv_smoke COMMAND vv_smoke)
  # [LLM-02] llama.cpp backend bridge; model cases need $VV_TEST_MODELS_DIR
  # (tools/ci/fetch_test_models.sh), otherwise they report SKIP (exit 77).
  add_executable(vv_llm_backend_test tests/llm_backend_test.c)
  target_link_libraries(vv_llm_backend_test PRIVATE vv_native)
  add_test(NAME vv_llm_backend COMMAND vv_llm_backend_test)
  set_tests_properties(vv_llm_backend PROPERTIES SKIP_RETURN_CODE 77)
  # [LLM-04] streaming engine (create/generate/cancel/destroy, memory).
  add_executable(vv_llm_engine_test tests/llm_engine_test.c)
  target_link_libraries(vv_llm_engine_test PRIVATE vv_native)
  add_test(NAME vv_llm_engine COMMAND vv_llm_engine_test)
  set_tests_properties(vv_llm_engine PROPERTIES SKIP_RETURN_CODE 77)
  # [LLM-03] big.LITTLE perf-core detection (fake sysfs) + CPU feature guard.
  add_executable(vv_cpu_test tests/cpu_test.c bridge/vv_cpu.c)
  target_include_directories(vv_cpu_test PRIVATE bridge)
  target_link_libraries(vv_cpu_test PRIVATE vv_native)
  add_test(NAME vv_cpu COMMAND vv_cpu_test ${CMAKE_CURRENT_BINARY_DIR}/cpu_test_sysfs)
  add_test(NAME vv_exports
    COMMAND ${CMAKE_COMMAND} -DLIB=$<TARGET_FILE:vv_native>
            -P ${CMAKE_CURRENT_SOURCE_DIR}/tests/check_exports.cmake)
endif()
