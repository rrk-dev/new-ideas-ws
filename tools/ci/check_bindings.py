#!/usr/bin/env python3
"""Every VV_API function in vv_bridge.h must have a generated Dart binding.

Cheap, deterministic drift guard (regenerating with ffigen needs libclang and
varies by clang version). Regenerate with:
  cd packages/vv_native && fvm dart run ffigen --config ffigen.yaml
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
header = (root / "native/bridge/vv_bridge.h").read_text()
bindings = (root / "packages/vv_native/lib/src/vv_bindings.g.dart").read_text()
declared = set(re.findall(r"VV_API\s+[\w\s\*]+?\b(vv_\w+)\s*\(", header))
bound = set(re.findall(r"\b(vv_\w+)\s*\(", bindings))
missing = sorted(declared - bound)
if not declared:
    sys.exit("check_bindings: found no VV_API functions in header")
if missing:
    sys.exit(f"check_bindings: not in Dart bindings: {missing} - rerun ffigen")
abi = re.search(r"VV_ABI_VERSION\s+(\d+)", header).group(1)
dart = (root / "packages/vv_native/lib/vv_native.dart").read_text()
if f"expectedAbiVersion = {abi};" not in dart:
    sys.exit(f"check_bindings: expectedAbiVersion != VV_ABI_VERSION ({abi})")
print(f"check_bindings: OK ({len(declared)} functions, abi {abi})")
