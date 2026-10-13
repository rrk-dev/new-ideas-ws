#!/usr/bin/env python3
"""Coverage gate: >= 80% lines over lib/core/** and lib/**/domain/** (vv-testing).

Usage: check_coverage.py <lcov.info> [threshold]
Generated code (*.g.dart, *.freezed.dart) is excluded.
"""
import re
import sys

THRESHOLD = float(sys.argv[2]) if len(sys.argv) > 2 else 80.0
GATED = re.compile(r"(^|/)lib/(core/|.+/domain/)")
GENERATED = re.compile(r"\.(g|freezed)\.dart$")


def parse(path):
    files, cur = {}, None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("SF:"):
            cur = line[3:]
            files[cur] = [0, 0]  # found, hit
        elif line.startswith("LF:") and cur:
            files[cur][0] = int(line[3:])
        elif line.startswith("LH:") and cur:
            files[cur][1] = int(line[3:])
    return files


def main():
    files = parse(sys.argv[1])
    gated = {f: v for f, v in files.items() if GATED.search(f) and not GENERATED.search(f)}
    found = sum(v[0] for v in gated.values())
    hit = sum(v[1] for v in gated.values())
    if found == 0:
        print("check_coverage: no gated files in report")
        return 1
    pct = 100.0 * hit / found
    print(f"check_coverage: {pct:.1f}% of {found} lines in {len(gated)} gated files (min {THRESHOLD:.0f}%)")
    if pct < THRESHOLD:
        for f, (lf, lh) in sorted(gated.items(), key=lambda kv: kv[1][1] / max(kv[1][0], 1)):
            if lf and lh < lf:
                print(f"  {f}: {lh}/{lf}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
