#!/usr/bin/env python3
"""Every VV_API function in the bridge headers must have a generated Dart binding.

Cheap, deterministic drift guard (regenerating with ffigen needs libclang and
varies by clang version). Scans every header listed under
`include-directives` in packages/vv_native/ffigen.yaml (the single ffigen
config: vv_bridge.h and the headers it includes) and checks that each is
included by vv_bridge.h, so the one bindings file covers the whole C ABI.
Regenerate with:
  cd packages/vv_native && fvm dart run ffigen --config ffigen.yaml
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
pkg = root / "packages/vv_native"
config = (pkg / "ffigen.yaml").read_text()
section = re.search(r"include-directives:\n((?:\s+-\s+.+\n)+)", config)
if not section:
    sys.exit("check_bindings: no include-directives in ffigen.yaml")
headers = [
    (pkg / h.strip()).resolve()
    for h in re.findall(r"-\s+(\S+)", section.group(1))
]
bridge = root / "native/bridge/vv_bridge.h"
bridge_src = bridge.read_text()
declared = set()
for h in headers:
    if not h.exists():
        sys.exit(f"check_bindings: {h} listed in ffigen.yaml does not exist")
    if h != bridge.resolve() and f'#include "{h.name}"' not in bridge_src:
        sys.exit(f"check_bindings: {h.name} is not included by vv_bridge.h")
    declared |= set(re.findall(r"VV_API\s+[\w\s\*]+?\b(vv_\w+)\s*\(", h.read_text()))
# Every bridge header must be bound by the single config.
listed = {h.name for h in headers}
for h in sorted((root / "native/bridge").glob("vv_*.h")):
    if f'#include "{h.name}"' in bridge_src and h.name not in listed:
        sys.exit(f"check_bindings: {h.name} is included by vv_bridge.h but not in ffigen.yaml")
bindings = (pkg / "lib/src/vv_bindings.g.dart").read_text()
bound = set(re.findall(r"\b(vv_\w+)\s*\(", bindings))
missing = sorted(declared - bound)
if not declared:
    sys.exit("check_bindings: found no VV_API functions in the bridge headers")
if missing:
    sys.exit(f"check_bindings: not in Dart bindings: {missing} - rerun ffigen")
extra = sorted(p.name for p in (pkg / "lib/src").glob("*bindings*.g.dart") if p.name != "vv_bindings.g.dart")
if extra:
    sys.exit(f"check_bindings: more than one generated bindings file: {extra}")
abi = re.search(r"VV_ABI_VERSION\s+(\d+)", bridge_src).group(1)
dart = (pkg / "lib/vv_native.dart").read_text()
if f"expectedAbiVersion = {abi};" not in dart:
    sys.exit(f"check_bindings: expectedAbiVersion != VV_ABI_VERSION ({abi})")
print(f"check_bindings: OK ({len(declared)} functions in {len(headers)} headers, abi {abi})")
