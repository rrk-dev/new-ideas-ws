"""Static checks for the whisper.cpp mobile build configuration (STT-01, STT-02).

The iOS/Android builds cannot run on every host; these tests pin the configuration the
ADRs depend on so a refactor of native/CMakeLists.txt or native/build.sh cannot silently
drop it. Runtime behaviour is covered by the host ctests (native/tests/stt_backends.cpp).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CMAKE = (ROOT / "native" / "CMakeLists.txt").read_text()
BUILD = (ROOT / "native" / "build.sh").read_text()


def _ios_block() -> str:
    m = re.search(r"build_ios\(\) \{(.*?)\n\}", BUILD, re.S)
    assert m, "build_ios() not found in native/build.sh"
    return m.group(1)


def test_STT_01_coreml_option_defaults_off_and_always_allows_fallback():
    """Core ML is opt-in and can never make whisper init fail when the encoder is absent."""
    m = re.search(r'option\(VV_WHISPER_COREML\s+"[^"]*"\s+(\w+)\)', CMAKE)
    assert m and m.group(1) == "OFF", "VV_WHISPER_COREML must default to OFF (ADR-STT-01)"
    block = CMAKE[CMAKE.index("if(VV_WHISPER_COREML)"):]
    block = block[: block.index("endif()\n", block.index("set(WHISPER_COREML_ALLOW_FALLBACK")) + 8]
    assert "set(WHISPER_COREML ON)" in block
    assert "set(WHISPER_COREML_ALLOW_FALLBACK ON)" in block
    # Must be configured before whisper.cpp is added, or the option is ignored.
    assert CMAKE.index("set(WHISPER_COREML ON)") < CMAKE.index("add_subdirectory(whisper.cpp")


def test_STT_01_ios_build_uses_embedded_metal_and_forwards_coreml_flag():
    """iOS slices: Metal on, shader library embedded, Core ML switch forwarded."""
    ios = _ios_block()
    for flag in ("-DGGML_METAL=ON", "-DGGML_METAL_EMBED_LIBRARY=ON", "-DGGML_METAL_TARGET_OS=ios",
                 "-DGGML_OPENMP=OFF", "-DGGML_NATIVE=OFF"):
        assert flag in ios, flag
    assert '-DVV_WHISPER_COREML="${VV_WHISPER_COREML:-OFF}"' in ios


def test_STT_01_cpu_fallback_backend_is_always_built():
    """The CPU backend (background path) must never be disabled for mobile targets."""
    assert "GGML_CPU OFF" not in CMAKE and "-DGGML_CPU=OFF" not in BUILD


def test_STT_01_AC2_adr_records_coreml_vs_metal_benchmark():
    """[STT-01/AC2] The Core ML decision is written down with measured numbers."""
    adr = (ROOT / "docs/adr/ADR-STT-01-ios-coreml-vs-metal.md").read_text()
    assert re.search(r"\*\*Status:\*\* (Proposed|Accepted)", adr)
    for needle in ("Metal-only", "Core ML enc", "RTF", "cold", "ONNX", "ExecuTorch"):
        assert needle in adr, needle
    # At least one measured wall time per option in the evidence table.
    assert len(re.findall(r"\d+\.\d+ s", adr)) >= 4
    raw = ROOT / "tools/bench/results/2026-10-13-stt-host-backends.jsonl"
    labels = {m for m in re.findall(r'"label":"([^"]+)"', raw.read_text())}
    assert {"metal", "cpu", "coreml+metal", "coreml+cpu"} <= labels


def _android_block() -> str:
    m = re.search(r"build_android\(\) \{(.*?)\n\}", BUILD, re.S)
    assert m, "build_android() not found in native/build.sh"
    return m.group(1)


def test_STT_02_runtime_cpu_variants_are_opt_in_and_exclusive_with_fixed_arch():
    """DL build = every CPU variant + runtime pick; never combined with a fixed -march."""
    m = re.search(r'option\(VV_GGML_BACKEND_DL\s+"[^"]*"\s+(\w+)\)', CMAKE)
    assert m and m.group(1) == "OFF"
    block = CMAKE[CMAKE.index("if(VV_GGML_BACKEND_DL)"):CMAKE.index("add_subdirectory(llama.cpp/ggml")]
    for needle in ("set(GGML_BACKEND_DL ON)", "set(GGML_CPU_ALL_VARIANTS ON)",
                   "set(BUILD_SHARED_LIBS ON)", "VV_ANDROID_CPU_ARCH and VV_GGML_BACKEND_DL",
                   "max-page-size=16384"):
        assert needle in block, needle
    # whisper/llama must go back to static right after ggml.
    after = CMAKE[CMAKE.index("add_subdirectory(llama.cpp/ggml"):CMAKE.index("add_subdirectory(llama.cpp llama)")]
    assert "set(BUILD_SHARED_LIBS OFF)" in after


def test_STT_02_gpu_backends_only_as_runtime_modules():
    """[STT-02/AC2] Vulkan/OpenCL can only be built as dlopen()ed modules (safe CPU fallback)."""
    assert 'GPU backends must be runtime-optional: set VV_GGML_BACKEND_DL=ON' in CMAKE
    for opt in ("VV_GGML_VULKAN", "VV_GGML_OPENCL"):
        m = re.search(rf'option\({opt}\s+"[^"]*"\s+(\w+)\)', CMAKE)
        assert m and m.group(1) == "OFF", opt
    android = _android_block()
    for flag in ('-DVV_GGML_BACKEND_DL="${VV_GGML_BACKEND_DL:-OFF}"',
                 '-DVV_GGML_VULKAN="${VV_GGML_VULKAN:-OFF}"',
                 '-DVV_GGML_OPENCL="${VV_GGML_OPENCL:-OFF}"',
                 "c++_shared", "-DGGML_OPENMP=OFF", "-DGGML_NATIVE=OFF"):
        assert flag in android, flag
    # NNAPI is deprecated (Android 15) and out of scope (ADR-STT-02).
    assert "NNAPI" not in CMAKE.upper().replace("# NNAPI", "")


def test_STT_02_bridge_exports_backend_api():
    """vv_backends_* and vv_cpu_perf_cores are exported on both linkers."""
    bridge = ROOT / "native" / "bridge"
    mp, txt = (bridge / "vv_exports.map").read_text(), (bridge / "vv_exports.txt").read_text()
    for sym in ("vv_backends_load", "vv_backends_describe", "vv_backends_dynamic", "vv_cpu_perf_cores"):
        assert f"{sym};" in mp and f"_{sym}\n" in txt, sym


def test_STT_03_stt_abi_is_exported_and_bound():
    """Every VV_API in vv_whisper.h is exported on both linkers and has an ffigen binding."""
    bridge = ROOT / "native" / "bridge"
    header = (bridge / "vv_whisper.h").read_text()
    declared = set(re.findall(r"VV_API\s+[\w\s\*]+?\b(vv_\w+)\s*\(", header))
    assert {"vv_stt_create", "vv_stt_transcribe_async", "vv_stt_transcribe_ranges",
            "vv_stt_cancel", "vv_stt_destroy", "vv_stt_free_segment"} <= declared
    mp, txt = (bridge / "vv_exports.map").read_text(), (bridge / "vv_exports.txt").read_text()
    bindings = (ROOT / "packages/vv_native/lib/src/vv_bindings.g.dart").read_text()
    for sym in declared:
        assert f"{sym};" in mp and f"_{sym}\n" in txt, f"{sym} not exported"
        assert re.search(rf"\b{sym}\s*\(", bindings), f"{sym} missing in bindings (rerun ffigen)"
    assert '#include "vv_whisper.h"' in (bridge / "vv_bridge.h").read_text()
