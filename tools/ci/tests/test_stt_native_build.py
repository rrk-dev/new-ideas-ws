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
