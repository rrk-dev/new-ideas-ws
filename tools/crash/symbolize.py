#!/usr/bin/env python3
"""Symbolize a VaultVoice crash report that a user shared (REL-02).

Runs on a developer machine only, against the PRIVATE symbol artifacts kept by
the release pipeline (REL-01: Dart `--split-debug-info` output, unstripped
`libvv_native.so`, dSYMs). Never upload reports or symbols to a third party.

  # native report (*.vvcrash), iOS/macOS -> atos, Android/Linux -> llvm-symbolizer/addr2line
  python3 tools/crash/symbolize.py native-20261013T101500Z.vvcrash --symbols path/to/symbols

  # Dart report (*.vvdart) from an obfuscated build -> `flutter symbolize`
  python3 tools/crash/symbolize.py dart-20261013T101500Z.vvdart \
      --dart-symbols build/symbols/android/app.android-arm64.symbols

`--symbols` is searched recursively for each module basename (`libvv_native.so`,
`vv_native`, `<name>.dSYM`, `<name>.debug`/`.dbg`). See docs/crash-triage.md.
Standard library only (runs with any python3 >= 3.9).
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

NATIVE_HEADER = "VaultVoice native crash report v"
DART_HEADER = "VaultVoice Dart error report v"
FRAME_RE = re.compile(r"^\s*#(?P<idx>\d+)\s+pc\s+(?P<rel>[0-9a-fA-F]+)\s+(?P<module>\S+)(?:\s+\(BuildId:\s*(?P<bid>[0-9a-fA-F]+)\))?")
MODULE_RE = re.compile(r"^\s*load\s+0x(?P<base>[0-9a-fA-F]+)\s+(?P<name>\S+)\s+(?P<bid>\S+)")
ABI_RE = re.compile(r"^ABI:\s*'(?P<abi>[^']+)'")


@dataclass
class Frame:
    index: int
    rel: int
    module: str
    build_id: str | None
    line: str
    symbol: str | None = None


@dataclass
class NativeReport:
    abi: str = "arm64"
    frames: list[Frame] = field(default_factory=list)
    loads: dict[str, int] = field(default_factory=dict)  # module -> load address
    build_ids: dict[str, str] = field(default_factory=dict)
    lines: list[str] = field(default_factory=list)


def kind_of(text: str) -> str:
    head = text[:4096]
    if DART_HEADER in head:
        return "dart"
    if NATIVE_HEADER in head:
        return "native"
    raise ValueError("not a VaultVoice crash report (header missing)")


def parse_native(text: str) -> NativeReport:
    rep = NativeReport(lines=text.splitlines())
    in_bt = False
    for ln in rep.lines:
        if m := ABI_RE.match(ln):
            rep.abi = m["abi"]
        if ln.startswith("backtrace:"):
            in_bt = True
            continue
        if ln.startswith("modules:"):
            in_bt = False
            continue
        if in_bt and (m := FRAME_RE.match(ln)):
            rep.frames.append(Frame(int(m["idx"]), int(m["rel"], 16), m["module"], m["bid"], ln))
        elif m := MODULE_RE.match(ln):
            rep.loads[m["name"]] = int(m["base"], 16)
            if m["bid"] != "-":
                rep.build_ids[m["name"]] = m["bid"]
    return rep


def find_symbol_file(module: str, roots: list[Path]) -> Path | None:
    """Best debug file for `module` under `roots` (dSYM DWARF > .debug/.dbg > binary)."""
    ranked: list[tuple[int, str, Path]] = []
    debug_names = (f"{module}.debug", f"{module}.dbg")
    for root in roots:
        if root.is_file():
            if root.name in (module, *debug_names):
                ranked.append((1 if root.name in debug_names else 2, str(root), root))
            continue
        for dirpath, _dirnames, filenames in os.walk(root):
            d = Path(dirpath)
            in_dsym = d.name == "DWARF" and d.parent.parent.name.startswith(f"{module}.") \
                and d.parent.parent.suffix == ".dSYM"
            for fn in filenames:
                if in_dsym:
                    ranked.append((0, str(d / fn), d / fn))
                elif fn in debug_names:
                    ranked.append((1, str(d / fn), d / fn))
                elif fn == module:
                    ranked.append((2, str(d / fn), d / fn))
    return min(ranked)[2] if ranked else None


def _which_symbolizer() -> list[str] | None:
    ndk = os.environ.get("ANDROID_NDK_HOME") or os.environ.get("ANDROID_NDK_ROOT")
    if ndk:
        prebuilt = Path(ndk) / "toolchains" / "llvm" / "prebuilt"
        if prebuilt.is_dir():
            for host in sorted(prebuilt.iterdir()):
                exe = host / "bin" / "llvm-symbolizer"
                if exe.exists():
                    return [str(exe)]
    for name in ("llvm-symbolizer", "addr2line"):
        if p := shutil.which(name):
            return [p]
    return None


def _is_macho(path: Path) -> bool:
    try:
        magic = path.read_bytes()[:4]
    except OSError:
        return False
    return magic in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe")


def symbolize_module(module: str, frames: list[Frame], rep: NativeReport, sym: Path) -> None:
    if _is_macho(sym):
        load = rep.loads.get(module)
        if load is None or not shutil.which("atos"):
            return
        arch = {"arm64": "arm64", "x86_64": "x86_64"}.get(rep.abi, rep.abi)
        cmd = ["atos", "-arch", arch, "-o", str(sym), "-l", hex(load)] + [hex(load + f.rel) for f in frames]
        out = subprocess.run(cmd, capture_output=True, text=True, check=False).stdout.splitlines()
        for f, s in zip(frames, out):
            s = s.strip()
            if s and not s.startswith("0x"):
                f.symbol = s
        return
    tool = _which_symbolizer()
    if tool is None:
        return
    if Path(tool[0]).name.startswith("addr2line"):
        for f in frames:  # one call per address: stable 2-line output (function, file:line)
            r = subprocess.run(tool + ["-f", "-C", "-e", str(sym), hex(f.rel)],
                               capture_output=True, text=True, check=False).stdout.splitlines()
            if len(r) >= 2 and r[0] != "??":
                f.symbol = f"{r[0]} ({r[1]})"
        return
    for f in frames:
        r = subprocess.run(tool + ["--obj", str(sym), "--functions=linkage", "--demangle", hex(f.rel)],
                           capture_output=True, text=True, check=False).stdout.split("\n\n")[0].splitlines()
        if len(r) >= 2 and r[0] != "??":
            f.symbol = f"{r[0]} ({r[1]})"


def symbolize_native(text: str, roots: list[Path]) -> str:
    rep = parse_native(text)
    by_module: dict[str, list[Frame]] = {}
    for f in rep.frames:
        by_module.setdefault(f.module, []).append(f)
    missing = []
    for module, frames in by_module.items():
        if module == "<unknown>":
            continue
        sym = find_symbol_file(module, roots)
        if sym is None:
            missing.append(module)
            continue
        symbolize_module(module, frames, rep, sym)
    annotated = {f.line: f for f in rep.frames}
    out = []
    for ln in rep.lines:
        f = annotated.get(ln)
        out.append(f"{ln}  -> {f.symbol}" if f and f.symbol else ln)
    if missing:
        out.append(f"# no symbols found for: {', '.join(sorted(missing))} (system libraries need the device's OS symbols)")
    return "\n".join(out) + "\n"


def dart_stack(text: str) -> str:
    """The raw `StackTrace.toString()` section of a Dart report."""
    lines = text.splitlines()
    try:
        start = lines.index("stack:") + 1
    except ValueError as e:
        raise ValueError("Dart report has no 'stack:' section") from e
    end = lines.index("end of report") if "end of report" in lines else len(lines)
    return "\n".join(lines[start:end]) + "\n"


def symbolize_dart(text: str, dart_symbols: Path | None, flutter: list[str]) -> str:
    stack = dart_stack(text)
    if dart_symbols is None:
        return text + "# pass --dart-symbols <app.<platform>-<arch>.symbols> to symbolize obfuscated frames\n"
    with tempfile.TemporaryDirectory() as tmp:
        trace = Path(tmp) / "stack.txt"
        trace.write_text(stack, encoding="utf-8")
        cmd = flutter + ["symbolize", "-i", str(trace), "-d", str(dart_symbols)]
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if r.returncode != 0:
            raise RuntimeError(f"flutter symbolize failed ({r.returncode}): {r.stderr.strip()[:400]}")
        head = text.split("stack:\n", 1)[0]
        return head + "stack (symbolized):\n" + r.stdout + "end of report\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("report", type=Path, help="crash report file the user shared")
    ap.add_argument("--symbols", type=Path, action="append", default=[],
                    help="directory/file with unstripped native libraries or dSYMs (repeatable)")
    ap.add_argument("--dart-symbols", type=Path, help="Dart split-debug-info .symbols file for this build/arch")
    ap.add_argument("--flutter", default=None, help="flutter command (default: 'fvm flutter' if fvm exists)")
    args = ap.parse_args(argv)
    text = args.report.read_text(encoding="utf-8", errors="replace")
    kind = kind_of(text)
    if kind == "native":
        sys.stdout.write(symbolize_native(text, args.symbols))
    else:
        flutter = args.flutter.split() if args.flutter else (["fvm", "flutter"] if shutil.which("fvm") else ["flutter"])
        sys.stdout.write(symbolize_dart(text, args.dart_symbols, flutter))
    return 0


if __name__ == "__main__":
    sys.exit(main())
