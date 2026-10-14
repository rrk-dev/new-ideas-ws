"""Invariants from the wave-2 integration (docs/adr/ADR-INT-W2-integration.md)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BRIDGE = ROOT / "native/bridge"
CMAKE = (ROOT / "native/CMakeLists.txt").read_text()
PKG = ROOT / "packages/vv_native"
APP = ROOT / "app/lib"


def test_gpu_backends_only_as_runtime_modules():
    """LLM-03's static GPU options are aliases of STT-02's DL module options."""
    assert "set(GGML_VULKAN ${VV_ANDROID_VULKAN})" not in CMAKE
    assert "set(GGML_OPENCL ${VV_ANDROID_OPENCL})" not in CMAKE
    assert not re.search(r"option\(VV_ANDROID_(VULKAN|OPENCL)\b", CMAKE)
    assert "set(VV_GGML_${_vv_gpu} ON)" in CMAKE
    alias = CMAKE.index("foreach(_vv_gpu VULKAN OPENCL)")
    guard = CMAKE.index("GPU backends must be runtime-optional")
    assert alias < guard, "aliases must be resolved before the DL guard"


def test_one_error_header():
    defs = {}
    for h in BRIDGE.glob("*.h"):
        for name in re.findall(r"#define\s+(VV_(?:OK|E_\w+))\s", h.read_text()):
            defs.setdefault(name, []).append(h.name)
    assert defs, "no VV_E_* codes found"
    assert all(files == ["vv_error.h"] for files in defs.values()), defs
    crash = (BRIDGE / "vv_crash.h").read_text()
    assert '#include "vv_error.h"' in crash
    assert "#define VV_CRASH_E_IO VV_E_IO" in crash


def test_single_ffigen_config_and_bindings():
    assert sorted(p.name for p in PKG.glob("ffigen*.yaml")) == ["ffigen.yaml"]
    assert sorted(p.name for p in (PKG / "lib/src").glob("*.g.dart")) == ["vv_bindings.g.dart"]
    bridge = (BRIDGE / "vv_bridge.h").read_text()
    for h in ("vv_error.h", "vv_whisper.h", "vv_llama.h", "vv_crash.h"):
        assert f'#include "{h}"' in bridge, h
        assert h in (PKG / "ffigen.yaml").read_text(), h


def test_exports_lists_contain_only_vv_symbols_and_perf_cores_once():
    m = (BRIDGE / "vv_exports.map").read_text()
    glob = re.search(r"global:(.*?)local:", m, re.S).group(1)
    syms = [s.strip().rstrip(";") for s in glob.split() if s.strip()]
    assert syms and all(s.startswith("vv_") for s in syms), syms
    assert syms.count("vv_cpu_perf_cores") == 1
    txt = [l.strip() for l in (BRIDGE / "vv_exports.txt").read_text().splitlines() if l.strip()]
    assert all(l.startswith("_vv_") for l in txt), txt
    assert txt.count("_vv_cpu_perf_cores") == 1
    defs = [h.name for h in BRIDGE.glob("*.c*") if re.search(r"^int32_t vv_cpu_perf_cores\(void\)\s*\{", h.read_text(), re.M)]
    assert defs == ["vv_llama.cpp"], defs


def test_one_dart_backend_policy():
    for gone in ("features/extraction/domain/gpu_backend_guard.dart",
                 "features/extraction/data/file_backend_health_store.dart"):
        assert not (APP / gone).exists(), gone
    code = "\n".join(p.read_text() for p in APP.rglob("*.dart"))
    sources = re.sub(r"^\s*//.*$", "", code, flags=re.M)  # ignore comments
    for name in ("GpuBackendGuard", "FileBackendHealthStore", "GpuAllowlist", "LlmBackendPolicy",
                 "chooseAndroidBackend"):
        assert not re.search(rf"\b{name}\b", sources), name
    assert len(re.findall(r"^enum GpuBackend\b", sources, re.M)) == 1
    policy = (APP / "features/extraction/domain/llm_backend_policy.dart").read_text()
    assert "chooseBackend(" in policy
