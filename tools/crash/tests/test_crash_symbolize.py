"""REL-02: forced native crash -> user-shared report file -> symbolicated trace.

Builds the real handler (native/bridge/vv_crash.c) with the host C compiler,
crashes it in a subprocess, copies the report the way a user would share it
(a lone file, no build tree next to it), then symbolizes it with
tools/crash/symbolize.py against the private symbols (dSYM / unstripped ELF).
Self-contained: no submodules or full native build needed.
"""
from __future__ import annotations

import importlib.util
import os
import platform
import re
import shutil
import signal
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
BRIDGE = ROOT / "native" / "bridge"
TEST_SRC = ROOT / "native" / "tests" / "crash_test.c"
SYMBOLIZE = ROOT / "tools" / "crash" / "symbolize.py"

_spec = importlib.util.spec_from_file_location("vv_symbolize", SYMBOLIZE)
sym = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
sys.modules["vv_symbolize"] = sym
_spec.loader.exec_module(sym)


def _cc() -> str | None:
    return os.environ.get("CC") or shutil.which("clang") or shutil.which("cc") or shutil.which("gcc")


def _line_of(path: Path, needle: str) -> int:
    for i, ln in enumerate(path.read_text().splitlines(), start=1):
        if needle in ln:
            return i
    raise AssertionError(f"{needle!r} not in {path}")


@pytest.fixture(scope="module")
def crash_exe(tmp_path_factory) -> Path:
    cc = _cc()
    if cc is None:
        pytest.skip("no C compiler on PATH")
    out = tmp_path_factory.mktemp("build")
    objs = []
    # Separate objects (kept on disk) so dsymutil can collect DWARF on macOS.
    for src in (BRIDGE / "vv_crash.c", TEST_SRC):
        obj = out / (src.stem + ".o")
        subprocess.run([cc, "-g", "-O0", "-fno-omit-frame-pointer", "-Wall", "-Wextra", "-Werror",
                        f"-I{BRIDGE}", "-c", str(src), "-o", str(obj)], check=True)
        objs.append(str(obj))
    exe = out / "vv_crash_test"
    subprocess.run([cc, "-g", *objs, "-o", str(exe)], check=True)
    if sys.platform == "darwin":
        subprocess.run(["dsymutil", str(exe)], check=True, capture_output=True)
    else:
        # Mimic the release pipeline: ship a stripped binary, keep the debug file private.
        objcopy = shutil.which("objcopy") or shutil.which("llvm-objcopy")
        if objcopy:
            subprocess.run([objcopy, "--only-keep-debug", str(exe), str(exe) + ".debug"], check=True)
    return exe


def _force_crash(exe: Path, kind: int, report: Path) -> subprocess.CompletedProcess:
    return subprocess.run([str(exe), "crash", str(kind), str(report)], capture_output=True, text=True,
                          timeout=60, check=False)


def test_REL_02_AC1_forced_native_crash_symbolicates_from_shared_file(crash_exe, tmp_path):
    """[REL-02/AC1] A forced native crash produces a symbolicated report from a user-shared file."""
    on_device = tmp_path / "device" / "crash"
    on_device.mkdir(parents=True)
    report = on_device / "native-current.vvcrash"
    r = _force_crash(crash_exe, 1, report)
    # The handler chained to the default action: the process really died of the fault.
    assert r.returncode in (-signal.SIGSEGV, -signal.SIGBUS), (r.returncode, r.stderr)

    # "User shares the file": only the report travels; symbols stay in the private artifact dir.
    shared = tmp_path / "inbox" / "native-20261013T101500Z.vvcrash"
    shared.parent.mkdir()
    shutil.copy(report, shared)
    text = shared.read_text()
    assert sym.kind_of(text) == "native"
    parsed = sym.parse_native(text)
    assert len(parsed.frames) >= 3
    assert parsed.frames[0].module == "vv_crash_test"
    assert "vv_crash_test" in parsed.loads

    if sys.platform != "darwin" and sym._which_symbolizer() is None:
        pytest.skip("no llvm-symbolizer/addr2line on this host (install binutils or set ANDROID_NDK_HOME)")
    out = subprocess.run([sys.executable, str(SYMBOLIZE), str(shared), "--symbols", str(crash_exe.parent)],
                         capture_output=True, text=True, check=True).stdout
    frame_lines = [ln for ln in out.splitlines() if re.match(r"\s*#\d+ pc ", ln)]
    # Frame #00 is the faulting store in vv_crash.c, with its exact source line.
    fault_line = _line_of(BRIDGE / "vv_crash.c", "*p = 42;")
    assert "vv_crash_force_segv" in frame_lines[0], out
    assert f"vv_crash.c:{fault_line}" in frame_lines[0], out
    # The caller chain is recovered (frame-pointer walk) and symbolized too.
    joined = "\n".join(frame_lines[:6])
    for fn in ("vv_crash_force", "crash_test_level2", "crash_test_level1"):
        assert fn in joined, out
    assert f"crash_test.c:{_line_of(TEST_SRC, 'int rc = vv_crash_force(kind);')}" in joined, out


def test_REL_02_AC1_abort_report_is_symbolicated(crash_exe, tmp_path):
    """[REL-02/AC1] abort() (SIGABRT, re-raised to the default action) is reported and symbolized."""
    report = tmp_path / "abort.vvcrash"
    r = _force_crash(crash_exe, 2, report)
    assert r.returncode == -signal.SIGABRT, (r.returncode, r.stderr)
    text = report.read_text()
    assert "(SIGABRT)" in text and text.rstrip().endswith("end of report")
    if sys.platform != "darwin" and sym._which_symbolizer() is None:
        pytest.skip("no symbolizer on this host")
    out = sym.symbolize_native(text, [crash_exe.parent])
    if "vv_crash_force_abort" not in out and sys.platform.startswith("linux") \
            and platform.machine() in ("x86_64", "AMD64"):
        # Known limit (ADR-REL-02): the handler only walks frame pointers (async-signal-safe);
        # glibc on x86_64 is built without them, so the walk stops inside libc's raise().
        pytest.skip("x86_64 glibc has no frame pointers: abort() trace stops in libc")
    assert "vv_crash_force_abort" in out, out
    assert "crash_test_level1" in out, out


def test_parse_native_report_sample():
    text = (
        "*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***\n"
        "VaultVoice native crash report v1\napp: 1.2.3+45 prod\nos: Linux 5.10 aarch64\nABI: 'arm64'\n"
        "time_unix: 1\nsignal 11 (SIGSEGV), code 1, fault addr 0x0000000000000000\nbacktrace:\n"
        "    #00 pc 0000000000001f40  libvv_native.so (BuildId: abcd)\n"
        "    #01 pc 00000000deadbeef  <unknown>\n"
        "modules:\n    load 0x0000007a00000000 libvv_native.so abcd\nend of report\n"
    )
    rep = sym.parse_native(text)
    assert [f.rel for f in rep.frames] == [0x1F40, 0xDEADBEEF]
    assert rep.frames[0].build_id == "abcd"
    assert rep.loads == {"libvv_native.so": 0x7A00000000}
    assert rep.abi == "arm64"
    # No symbols available: report passes through unchanged (plus a hint), never crashes.
    out = sym.symbolize_native(text, [])
    assert "#01 pc 00000000deadbeef  <unknown>" in out
    assert "no symbols found for: libvv_native.so" in out


def test_dart_report_uses_flutter_symbolize(tmp_path):
    text = (
        "*** VaultVoice Dart error report v1\napp: 1.0.0+1 prod\nerror_type: StateError\nstack:\n"
        "*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***\n"
        "    #00 abs 000000727d0d9a4b virt 00000000002a9a4b _kDartIsolateSnapshotInstructions+0x1d1a4b\n"
        "end of report\n"
    )
    assert sym.kind_of(text) == "dart"
    assert "_kDartIsolateSnapshotInstructions" in sym.dart_stack(text)
    fake = tmp_path / "fake_flutter.py"
    fake.write_text(
        "import sys\nargs=sys.argv[1:]\nassert args[0]=='symbolize'\n"
        "i=args[args.index('-i')+1]; d=args[args.index('-d')+1]\n"
        "assert 'virt 00000000002a9a4b' in open(i).read()\n"
        "print('#0  main (package:vaultvoice/main_prod.dart:7:3) using '+d.split('/')[-1])\n"
    )
    symbols = tmp_path / "app.android-arm64.symbols"
    symbols.write_text("x")
    out = sym.symbolize_dart(text, symbols, [sys.executable, str(fake)])
    assert "stack (symbolized):" in out
    assert "main_prod.dart:7:3) using app.android-arm64.symbols" in out
    assert "error_type: StateError" in out


def test_rejects_unknown_files():
    with pytest.raises(ValueError):
        sym.kind_of("hello")


def test_every_crash_api_has_a_dart_binding():
    """vv_crash.h is bound by the single packages/vv_native/ffigen.yaml (via vv_bridge.h)."""
    header = (BRIDGE / "vv_crash.h").read_text()
    declared = set(re.findall(r"VV_API\s+[\w\s\*]+?\b(vv_\w+)\s*\(", header))
    bindings = (ROOT / "packages/vv_native/lib/src/vv_bindings.g.dart").read_text()
    bound = set(re.findall(r"\b(vv_\w+)\s*\(", bindings))
    assert declared and declared <= bound, sorted(declared - bound)
    for exports in ("vv_exports.map", "vv_exports.txt"):
        assert "vv_crash_" in (BRIDGE / exports).read_text(), exports
